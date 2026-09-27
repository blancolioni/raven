with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Raven.Objects;
with Raven.Strings;
with Raven.Parser;

package body Raven.Loader is

   use type Raven.Target.Library_Id;

   package String_Vectors is
     new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  The libraries being read, innermost last.  A library that asks
   --  for one already here has asked for itself, by however long a way
   --  round, and gets what has been read of it so far.

   Loading : String_Vectors.Vector;

   function File_Name (Name : String) return String;

   function Find_File
     (Target : Raven.Target.Reference;
      Name   : String)
      return String;

   function Is_Head
     (Target : Raven.Target.Reference;
      Name   : String)
      return Boolean;

   function Library_Name
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return String;

   --  A library asked for by name is looked for on the target's
   --  library path.  One that is loaded already is not read again,
   --  which is also what stops a cycle of imports.

   function Load
     (Target : Raven.Target.Reference;
      Name   : String)
      return Raven.Target.Library_Id;

   --  A file given a path is read whether or not a library of this
   --  name is loaded, into that library if there is one.

   function Load_File
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
      return Raven.Target.Library_Id;

   --  Abandoned counts the forms of this library that could not be
   --  run, and is what says at the end whether the library read
   --  whole.  It counts only the library's own: one it imports keeps
   --  its own count and is refused on its own account.

   procedure Read_Begin
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Source    : String;
      Abandoned : in out Natural);

   procedure Read_Declaration
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Source    : String;
      Abandoned : in out Natural);

   procedure Read_Export
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id);

   function Read_File (Path : String) return String;

   --  Name is what the reader calls the source it is reading, and is
   --  the path it was read from: it is what a complaint about a form
   --  says before the line.

   procedure Read_Forms
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Name      : String;
      Source    : String;
      Directory : String;
      Abandoned : in out Natural);

   procedure Read_Import
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id);

   procedure Read_Include
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Abandoned : in out Natural);

   procedure Read_Library
     (Target    : Raven.Target.Reference;
      Directory : String;
      Source    : String);

   function Read_Names
     (Target : Raven.Target.Reference)
      return String_Vectors.Vector;

   function Read_Text
     (Target : Raven.Target.Reference;
      Form   : Object)
      return String;

   procedure Report
     (Target  : Raven.Target.Reference;
      Message : String);

   --  A form read as far as it could be and then given up on: said
   --  where errors go, and counted where the host can ask.  A run
   --  that abandons a form used to look exactly like one that did
   --  not, which is how sixteen tests went missing without the suite
   --  reporting a single failure.

   procedure Abandon
     (Target    : Raven.Target.Reference;
      Start     : String;
      Head      : String;
      What      : String;
      Abandoned : in out Natural);

   --  The library to import, or none where it did not read whole.

   function Usable
     (Target : Raven.Target.Reference;
      Name   : String;
      Id     : Raven.Target.Library_Id)
      return Raven.Target.Library_Id;

   --  The head of the form on the target's stack, for saying which
   --  form was given up on.  Only the head, because the form itself
   --  may be the whole of a library.

   function Form_Head
     (Target : Raven.Target.Reference)
      return String;

   function Form_Head_Of
     (Target : Raven.Target.Reference;
      Form   : Object)
      return String;

   -------------
   -- Abandon --
   -------------

   procedure Abandon
     (Target    : Raven.Target.Reference;
      Start     : String;
      Head      : String;
      What      : String;
      Abandoned : in out Natural)
   is
      Where : constant String := (if Start = "" then "" else Start & ": ");
      Which : constant String :=
                (if Head = "" then "a form" else Head);
      Why   : constant String := (if What = "" then "" else ": " & What);
   begin
      Target.Abandon_Form;
      Abandoned := Abandoned + 1;
      Report (Target, Where & Which & " abandoned" & Why);
   end Abandon;

   ---------------
   -- File_Name --
   ---------------

   function File_Name (Name : String) return String is
      use Ada.Strings.Fixed;
      Result : String := Name;
      Last   : Natural := 0;
   begin
      --  (scheme base) is scheme/base.scm: the parentheses go, and
      --  what separated the parts of the name separates the parts of
      --  the path.

      for Ch of Result loop
         if Ch = ' ' then
            Ch := '/';
         end if;
      end loop;

      Last := Index (Result, ")", Ada.Strings.Backward);

      return Trim
        (Result ((if Result (Result'First) = '(' then Result'First + 1
                  else Result'First)
                 .. (if Last = 0 then Result'Last else Last - 1)),
         Ada.Strings.Both)
        & ".scm";
   end File_Name;

   ---------------
   -- Find_File --
   ---------------

   function Find_File
     (Target : Raven.Target.Reference;
      Name   : String)
      return String
   is
      Relative : constant String := File_Name (Name);
      Index    : Positive := 1;
   begin
      loop
         declare
            Directory : constant String := Target.Library_Path (Index);
         begin
            exit when Directory = "";
            if Ada.Directories.Exists (Directory & "/" & Relative) then
               return Directory & "/" & Relative;
            end if;
            Index := Index + 1;
         end;
      end loop;
      return "";
   end Find_File;

   ---------------
   -- Form_Head --
   ---------------

   function Form_Head
     (Target : Raven.Target.Reference)
      return String
   is (Form_Head_Of (Target, Target.Top));

   ------------------
   -- Form_Head_Of --
   ------------------

   function Form_Head_Of
     (Target : Raven.Target.Reference;
      Form   : Object)
      return String
   is
   begin
      if Raven.Objects.Is_Pair (Form) then
         return "(" & Target.Show (Target.Car (Form)) & " ...)";
      else
         return Target.Show (Form);
      end if;
   end Form_Head_Of;

   ------------
   -- Import --
   ------------

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
   is
      Library : constant Raven.Target.Library_Id :=
                  Usable (Target, Name, Load_File (Target, Name, Path));
   begin
      if Library /= Raven.Target.No_Library then
         Target.Add_Import (Target.Interaction_Library, Library);
      end if;
   end Import;

   -------------
   -- Is_Head --
   -------------

   function Is_Head
     (Target : Raven.Target.Reference;
      Name   : String)
      return Boolean
   is
      Form : constant Object := Target.Top;
   begin
      return Raven.Objects.Is_Pair (Form)
        and then Target.Car (Form) = Target.To_Symbol (Name);
   end Is_Head;

   ------------------
   -- Library_Name --
   ------------------

   function Library_Name
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return String
   is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String := To_Unbounded_String ("(");
      It     : Object := Spec;
   begin
      while Raven.Objects.Is_Pair (It) loop
         declare
            Part : constant Object := Target.Car (It);
         begin
            if Length (Result) > 1 then
               Append (Result, ' ');
            end if;
            Append (Result, Target.Show (Part));
         end;
         It := Target.Cdr (It);
      end loop;
      Append (Result, ')');
      return To_String (Result);
   end Library_Name;

   ----------
   -- Load --
   ----------

   function Load
     (Target : Raven.Target.Reference;
      Name   : String)
      return Raven.Target.Library_Id
   is
      Loaded : constant Raven.Target.Library_Id := Target.Library (Name);
   begin
      if Loading.Contains (Name) then
         Report (Target, "import: " & Name & " imports itself");
         return Loaded;
      elsif Loaded /= Raven.Target.No_Library then
         return Usable (Target, Name, Loaded);
      end if;

      declare
         Path : constant String := Find_File (Target, Name);
      begin
         if Path = "" then
            Report (Target, "import: no library " & Name);
            return Raven.Target.No_Library;
         end if;
         return Usable (Target, Name, Load_File (Target, Name, Path));
      end;
   end Load;

   ---------------
   -- Load_File --
   ---------------

   function Load_File
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
      return Raven.Target.Library_Id
   is
      Found   : constant Raven.Target.Library_Id := Target.Library (Name);
      Library : constant Raven.Target.Real_Library_Id :=
                  (if Found = Raven.Target.No_Library
                   then Target.Create_Library (Name)
                   else Found);
   begin
      Loading.Append (Name);

      --  The reader is opened on the path rather than the library's
      --  name, because a complaint saying which file and line to open
      --  is worth more than one naming the library it was in.

      declare
         Abandoned : Natural := 0;
      begin
         Read_Forms
           (Target, Library, Path, Read_File (Path),
            Ada.Directories.Containing_Directory (Path), Abandoned);

         --  A file read under a library's name is that library, so a
         --  form of it that could not be run leaves it half made in
         --  the same way one inside a define-library does.

         if Abandoned > 0 then
            Target.Set_Incomplete (Library);
            Report
              (Target,
               Name & " did not read whole:" & Abandoned'Image
               & " of its forms could not be run");
         end if;
      end;

      Loading.Delete_Last;
      return Library;

   exception
      when E : others =>
         Report (Target, Name & ": " & Ada.Exceptions.Exception_Message (E));
         if not Loading.Is_Empty then
            Loading.Delete_Last;
         end if;
         return Library;
   end Load_File;

   ----------------
   -- Read_Begin --
   ----------------

   procedure Read_Begin
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Source    : String;
      Abandoned : in out Natural)
   is
   begin
      --  What is left to read stays on the stack, which the collector
      --  walks.  Translating a form runs the machine, and nothing here
      --  could hold the rest of the list across that.

      Target.Push (Target.Cdr (Target.Pop));

      while Raven.Objects.Is_Pair (Target.Top) loop

         --  A form that cannot be run used to take the rest of the
         --  library with it: it raised out of this loop and out of
         --  the declaration, and the whole define-library was given
         --  up on, so everything after the bad form went undefined
         --  and only the first of them was ever heard about.
         --
         --  Carrying on means saying where to carry on from, because
         --  a form that fails part way through leaves the machine's
         --  stack wherever it had got to, and the rest of this list
         --  is on it.

         Target.Hold_Stack;

         declare
            --  The file, and no line: the whole library was read as
            --  one form, so nothing recorded where inside it each of
            --  these started.

            Start : constant String := Source;
            Head  : constant String := Form_Head_Of (Target,
                                                     Target.Car
                                                       (Target.Top));
         begin
            Target.Push (Target.Car (Target.Top));
            Target.Translate (Library);
            Target.Execute;
            Target.Drop;
            Target.Release_Stack (Restore => False);
         exception
            when E : Raven.Target.Undefined_Symbol =>
               Target.Release_Stack (Restore => True);
               Abandon
                 (Target, Start, Head,
                  "undefined: " & Ada.Exceptions.Exception_Message (E),
                  Abandoned);

            when Raven.Target.Translation_Error =>
               Target.Release_Stack (Restore => True);
               Abandon (Target, Start, Head, "", Abandoned);
         end;

         Target.Push (Target.Cdr (Target.Pop));
      end loop;

      Target.Drop;
   end Read_Begin;

   ----------------------
   -- Read_Declaration --
   ----------------------

   procedure Read_Declaration
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Source    : String;
      Abandoned : in out Natural)
   is
   begin
      if Is_Head (Target, "export") then
         Read_Export (Target, Library);
      elsif Is_Head (Target, "import") then
         Read_Import (Target, Library);
      elsif Is_Head (Target, "begin") then
         Read_Begin (Target, Library, Source, Abandoned);
      elsif Is_Head (Target, "include") then
         Read_Include (Target, Library, Directory, Abandoned);
      else
         Report
           (Target,
            "define-library: not a declaration: "
            & Target.Show (Target.Top));
         Target.Drop;
      end if;
   end Read_Declaration;

   -----------------
   -- Read_Export --
   -----------------

   procedure Read_Export
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id)
   is
      Names : constant String_Vectors.Vector := Read_Names (Target);
   begin
      Target.Drop;
      for Name of Names loop
         Target.Add_Export (Library, Name);
      end loop;
   end Read_Export;

   ---------------
   -- Read_File --
   ---------------

   function Read_File (Path : String) return String is
      use Ada.Text_IO;
      use Ada.Strings.Unbounded;

      File : File_Type;
      Buf  : Unbounded_String := Null_Unbounded_String;
   begin
      Open (File, In_File, Path);

      while not End_Of_File (File) loop
         declare
            Line : constant String := Get_Line (File);
         begin
            Append (Buf, Line);
            Append (Buf, ASCII.LF);
         end;
      end loop;

      Close (File);
      return To_String (Buf);
   end Read_File;

   ----------------
   -- Read_Forms --
   ----------------

   procedure Read_Forms
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Name      : String;
      Source    : String;
      Directory : String;
      Abandoned : in out Natural)
   is
      use Ada.Strings.Unbounded;
      Reader : Raven.Parser.Instance;
   begin
      Reader.Open (Name, Source);

      while not Reader.At_End loop

         --  A form that names something undefined is reported and the
         --  rest of the file is read anyway.  Anything else stops the
         --  read, and is reported where the file was opened.
         --
         --  Where the form started is asked for before it is read,
         --  because afterwards the reader has gone past it, and its
         --  head once it is on the stack.  Both are for saying which
         --  form was given up on: the message used to name whatever
         --  was undefined at the moment it failed and nothing else,
         --  so "undefined: first" pointed at a variable bound inside
         --  a procedure called by a form, rather than at the form.

         declare
            Start : constant String := Reader.Where;
            Head  : Unbounded_String := Null_Unbounded_String;
         begin
            Reader.Parse_Next (Target);
            Head := To_Unbounded_String (Form_Head (Target));

            if Is_Head (Target, "import") then
               Read_Import (Target, Library);
            elsif Is_Head (Target, "define-library") then

               --  A library keeps a count of its own: a file that
               --  holds one is not made incomplete by it, and the
               --  library is refused on its own account.

               Read_Library (Target, Directory, Name);
            else
               Target.Translate (Library);
               Target.Execute;
               Target.Drop;
            end if;
         exception
            when E : Raven.Target.Undefined_Symbol =>
               Abandon
                 (Target, Start, To_String (Head),
                  "undefined: " & Ada.Exceptions.Exception_Message (E),
                  Abandoned);

            --  A form the translator refuses is reported and the file
            --  goes on to the one after it, which is what an
            --  undefined name in a form has always done.  It could
            --  not be caught here before, because Translate reported
            --  it and returned as though nothing were wrong.
            --
            --  The translator has said what was wrong with it
            --  already; what is added here is that the form went no
            --  further.

            when Raven.Target.Translation_Error =>
               Abandon (Target, Start, To_String (Head), "", Abandoned);
         end;
      end loop;

      Reader.Close;
   end Read_Forms;

   -----------------
   -- Read_Import --
   -----------------

   procedure Read_Import
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id)
   is
      Names : String_Vectors.Vector;
      It    : Object := Target.Cdr (Target.Top);
   begin
      --  Everything the declaration asks for is taken out of it before
      --  anything is loaded: loading runs the machine, and nothing
      --  here could hold a form across that.

      while Raven.Objects.Is_Pair (It) loop
         declare
            Spec : constant Object := Target.Car (It);
         begin
            if Raven.Objects.Is_Pair (Spec) then
               Names.Append (Library_Name (Target, Spec));
            else
               Report
                 (Target,
                  "import: a library name is a list, not "
                  & Target.Show (Spec));
            end if;
         end;
         It := Target.Cdr (It);
      end loop;

      Target.Drop;

      for Name of Names loop
         declare
            Id : constant Raven.Target.Library_Id := Load (Target, Name);
         begin
            if Id /= Raven.Target.No_Library then
               Target.Add_Import (Library, Id);
            end if;
         end;
      end loop;
   end Read_Import;

   ------------------
   -- Read_Include --
   ------------------

   procedure Read_Include
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Abandoned : in out Natural)
   is
      Files : String_Vectors.Vector;
      It    : Object := Target.Cdr (Target.Top);
   begin
      while Raven.Objects.Is_Pair (It) loop
         Files.Append (Read_Text (Target, Target.Car (It)));
         It := Target.Cdr (It);
      end loop;

      Target.Drop;

      for File of Files loop

         --  Beside the library that includes it, which is the only
         --  place a library can say where its own text is.

         Read_Forms
           (Target, Library, Directory & "/" & File,
            Read_File (Directory & "/" & File),
            Directory, Abandoned);
      end loop;
   end Read_Include;

   ------------------
   -- Read_Library --
   ------------------

   procedure Read_Library
     (Target    : Raven.Target.Reference;
      Directory : String;
      Source    : String)
   is
      Abandoned : Natural := 0;
      Name    : constant String :=
                  Library_Name (Target, Target.Cadr (Target.Top));
      Found   : constant Raven.Target.Library_Id := Target.Library (Name);
      Library : constant Raven.Target.Real_Library_Id :=
                  (if Found = Raven.Target.No_Library
                   then Target.Create_Library (Name)
                   else Found);
   begin
      --  A library that says what it is offers nothing until it says
      --  what it offers.  A file that does not say is a library that
      --  offers everything it defines.

      Target.Set_Export_List (Library);

      --  The declarations are left on the stack, which the collector
      --  walks: reading one runs the machine, and nothing here could
      --  hold a form across that.

      Target.Push (Target.Cddr (Target.Pop));

      while Raven.Objects.Is_Pair (Target.Top) loop
         Target.Push (Target.Car (Target.Top));
         Read_Declaration (Target, Library, Directory, Source, Abandoned);
         Target.Push (Target.Cdr (Target.Pop));
      end loop;

      Target.Drop;

      --  Every form of it has been read, so every bad one in it has
      --  been heard about and not only the first.  And now nothing
      --  imports it: a library is a unit or it is nothing, and the
      --  names it never got round to defining would otherwise go
      --  undefined at each use, a long way from the reason.

      if Abandoned > 0 then
         Target.Set_Incomplete (Library);
         Report
           (Target,
            Name & " did not read whole:" & Abandoned'Image
            & " of its forms could not be run");
      end if;
   end Read_Library;

   ----------------
   -- Read_Names --
   ----------------

   function Read_Names
     (Target : Raven.Target.Reference)
      return String_Vectors.Vector
   is
      Names : String_Vectors.Vector;
      It    : Object := Target.Cdr (Target.Top);
   begin
      while Raven.Objects.Is_Pair (It) loop
         declare
            Name : constant Object := Target.Car (It);
         begin
            if Raven.Objects.Is_Symbol (Name) then
               Names.Append
                 (Target.To_String (Raven.Objects.To_Symbol (Name)));
            else
               Report (Target, "expected a name, not " & Target.Show (Name));
            end if;
         end;
         It := Target.Cdr (It);
      end loop;
      return Names;
   end Read_Names;

   ---------------
   -- Read_Text --
   ---------------

   function Read_Text
     (Target : Raven.Target.Reference;
      Form   : Object)
      return String
   is
   begin
      if not Raven.Objects.Is_Foreign_Value (Form)
        or else not Raven.Strings.Is_String (Target.To_Foreign_Value (Form))
      then
         Report (Target, "expected a string, not " & Target.Show (Form));
         return "";
      end if;

      return Raven.Strings.Text (Target.To_Foreign_Value (Form));
   end Read_Text;

   ------------
   -- Report --
   ------------

   procedure Report
     (Target  : Raven.Target.Reference;
      Message : String)
   is
   begin
      --  Where the host said errors go.  This wrote to the terminal
      --  whatever the host asked for, so a host holding everything a
      --  program wrote still saw these go past it.

      Target.Report_Error (Message);
   end Report;

   ----------------------
   -- Take_Declaration --
   ----------------------

   function Take_Declaration
     (Target : Raven.Target.Reference)
      return Boolean
   is
   begin
      if Is_Head (Target, "import") then
         Read_Import (Target, Target.Interaction_Library);
         return True;
      elsif Is_Head (Target, "define-library") then

         --  A library typed at the host has no file, so an include in
         --  it is looked for beside where the host is running, and a
         --  form of it that cannot be run has nowhere to say it came
         --  from but the host itself.

         Read_Library (Target, ".", "user input");
         return True;
      else
         return False;
      end if;
   end Take_Declaration;

   ------------
   -- Usable --
   ------------

   function Usable
     (Target : Raven.Target.Reference;
      Name   : String;
      Id     : Raven.Target.Library_Id)
      return Raven.Target.Library_Id
   is
   begin
      if Id /= Raven.Target.No_Library and then Target.Is_Incomplete (Id) then
         Report (Target, "import: " & Name & " did not read whole");
         return Raven.Target.No_Library;
      end if;

      return Id;
   end Usable;

end Raven.Loader;
