with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Raven.Features;
with Raven.Objects;
with Raven.Strings;
with Raven.Parser;

package body Raven.Loader is

   use type Raven.Target.Library_Id;

   package String_Vectors is
     new Ada.Containers.Indefinite_Vectors (Positive, String);

   package String_Maps is
     new Ada.Containers.Indefinite_Ordered_Maps (String, String);

   --  An import set (#27), read out of the declaration before anything
   --  is loaded: the library, and what is done to what it offers,
   --  innermost first.  A rename's names are in pairs, from and to.

   type Set_Kind is (Only, Except, Prefix, Rename);

   type Set_Step is
      record
         Kind  : Set_Kind;
         Names : String_Vectors.Vector;
      end record;

   package Step_Vectors is
     new Ada.Containers.Vectors (Positive, Set_Step);

   type Import_Request is
      record
         Library : Ada.Strings.Unbounded.Unbounded_String;
         Steps   : Step_Vectors.Vector;
      end record;

   package Request_Vectors is
     new Ada.Containers.Vectors (Positive, Import_Request);

   --  Whether Spec is an import set rather than a library name: one of
   --  the four, and then a list.  (only) on its own, or (prefix foo),
   --  is a library that happens to be called that.

   function Is_Import_Set
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return Boolean;

   --  Read Spec into Request, or say what is wrong with it and return
   --  False.

   function Parse_Import_Set
     (Target  : Raven.Target.Reference;
      Spec    : Object;
      Request : in out Import_Request)
      return Boolean;

   --  The names an import set gives, each against what Library exports
   --  it as, or say what is wrong and return False.

   function Import_Set_Names
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id;
      Request : Import_Request;
      Names   : out String_Maps.Map)
      return Boolean;

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

   --  The declarations of the first clause whose requirement holds, read
   --  as though they had been written where the cond-expand is.

   procedure Read_Cond_Expand
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Source    : String;
      Abandoned : in out Natural);

   procedure Read_Export
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id);

   --  (rename internal external), with both of them names.

   function Is_Rename
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return Boolean;

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

   ----------------------
   -- Import_Set_Names --
   ----------------------

   function Import_Set_Names
     (Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id;
      Request : Import_Request;
      Names   : out String_Maps.Map)
      return Boolean
   is
      use Ada.Strings.Unbounded;

      Name_Of : constant String := To_String (Request.Library);

      function Missing (Step : String; Name : String) return Boolean;
      procedure Offered (Name : String);

      -------------
      -- Missing --
      -------------

      function Missing (Step : String; Name : String) return Boolean is
      begin
         Report
           (Target,
            "import: " & Step & ": " & Name & " is not offered by "
            & Name_Of);
         return False;
      end Missing;

      -------------
      -- Offered --
      -------------

      procedure Offered (Name : String) is
      begin
         Names.Include (Name, Name);
      end Offered;

   begin
      Names.Clear;
      Target.Iterate_Exports (Library, Offered'Access);

      for Step of Request.Steps loop
         declare
            Result : String_Maps.Map;
         begin
            case Step.Kind is
               when Only =>
                  for Name of Step.Names loop
                     if not Names.Contains (Name) then
                        return Missing ("only", Name);
                     end if;
                     Result.Include (Name, Names (Name));
                  end loop;

               when Except =>
                  Result := Names;
                  for Name of Step.Names loop
                     if not Result.Contains (Name) then
                        return Missing ("except", Name);
                     end if;
                     Result.Delete (Name);
                  end loop;

               when Prefix =>
                  for Position in Names.Iterate loop
                     Result.Include
                       (Step.Names.First_Element & String_Maps.Key (Position),
                        String_Maps.Element (Position));
                  end loop;

               when Rename =>

                  --  All at once: (rename (a b) (b a)) swaps them.

                  Result := Names;
                  for Index in 1 .. Step.Names.Last_Index / 2 loop
                     declare
                        From : constant String := Step.Names (2 * Index - 1);
                     begin
                        if not Names.Contains (From) then
                           return Missing ("rename", From);
                        end if;
                        Result.Exclude (From);
                     end;
                  end loop;
                  for Index in 1 .. Step.Names.Last_Index / 2 loop
                     Result.Include
                       (Step.Names (2 * Index),
                        Names (Step.Names (2 * Index - 1)));
                  end loop;
            end case;

            Names := Result;
         end;
      end loop;

      return True;
   end Import_Set_Names;

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

   -------------------
   -- Is_Import_Set --
   -------------------

   function Is_Import_Set
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return Boolean
   is
      use Raven.Objects;
   begin
      if not Is_Pair (Spec)
        or else not Is_Symbol (Target.Car (Spec))
        or else not Is_Pair (Target.Cdr (Spec))
        or else not Is_Pair (Target.Cadr (Spec))
      then
         return False;
      end if;

      declare
         Head : constant String :=
                  Target.To_String (To_Symbol (Target.Car (Spec)));
      begin
         return Head = "only" or else Head = "except"
           or else Head = "prefix" or else Head = "rename";
      end;
   end Is_Import_Set;

   ---------------
   -- Is_Rename --
   ---------------

   function Is_Rename
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return Boolean
   is
      use Raven.Objects;
   begin
      return Is_Pair (Spec)
        and then Target.Car (Spec) = Target.To_Symbol ("rename")
        and then Is_Pair (Target.Cdr (Spec))
        and then Is_Symbol (Target.Cadr (Spec))
        and then Is_Pair (Target.Cddr (Spec))
        and then Is_Symbol (Target.Car (Target.Cddr (Spec)))
        and then Target.Cdr (Target.Cddr (Spec)) = Nil;
   end Is_Rename;

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

   ----------------------
   -- Parse_Import_Set --
   ----------------------

   function Parse_Import_Set
     (Target  : Raven.Target.Reference;
      Spec    : Object;
      Request : in out Import_Request)
      return Boolean
   is
      use Raven.Objects;

      function Name_Of (Item : Object) return String
      is (Target.To_String (To_Symbol (Item)));

      function Wrong (What : String) return Boolean;

      -----------
      -- Wrong --
      -----------

      function Wrong (What : String) return Boolean is
      begin
         Report (Target, "import: " & What & ", in " & Target.Show (Spec));
         return False;
      end Wrong;

   begin
      if not Is_Import_Set (Target, Spec) then
         Request.Library :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (Library_Name (Target, Spec));
         return True;
      end if;

      if not Parse_Import_Set (Target, Target.Cadr (Spec), Request) then
         return False;
      end if;

      declare
         Head : constant String := Name_Of (Target.Car (Spec));
         Step : Set_Step :=
                  (Kind  => Set_Kind'Value (Head),
                   Names => String_Vectors.Empty_Vector);
         It   : Object := Target.Cddr (Spec);
      begin
         while Is_Pair (It) loop
            declare
               Item : constant Object := Target.Car (It);
            begin
               if Step.Kind /= Rename and then Is_Symbol (Item) then
                  Step.Names.Append (Name_Of (Item));
               elsif Step.Kind = Rename
                 and then Is_Pair (Item)
                 and then Is_Symbol (Target.Car (Item))
                 and then Is_Pair (Target.Cdr (Item))
                 and then Is_Symbol (Target.Cadr (Item))
                 and then Target.Cddr (Item) = Nil
               then
                  Step.Names.Append (Name_Of (Target.Car (Item)));
                  Step.Names.Append (Name_Of (Target.Cadr (Item)));
               elsif Step.Kind = Rename then
                  return Wrong
                    ("rename: expected (from to), not " & Target.Show (Item));
               else
                  return Wrong
                    (Head & ": expected a name, not " & Target.Show (Item));
               end if;
            end;
            It := Target.Cdr (It);
         end loop;

         if Step.Kind = Prefix and then Step.Names.Last_Index /= 1 then
            return Wrong ("prefix: expected one prefix");
         end if;

         Request.Steps.Append (Step);
      end;

      return True;
   end Parse_Import_Set;

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
               Target.Reset_Dynamic_State;
               Target.Release_Stack (Restore => True);
               Abandon
                 (Target, Start, Head,
                  "undefined: " & Ada.Exceptions.Exception_Message (E),
                  Abandoned);

            when Raven.Target.Translation_Error =>
               Target.Reset_Dynamic_State;
               Target.Release_Stack (Restore => True);
               Abandon (Target, Start, Head, "", Abandoned);
         end;

         Target.Push (Target.Cdr (Target.Pop));
      end loop;

      Target.Drop;
   end Read_Begin;

   ----------------------
   -- Read_Cond_Expand --
   ----------------------

   procedure Read_Cond_Expand
     (Target    : Raven.Target.Reference;
      Library   : Raven.Target.Real_Library_Id;
      Directory : String;
      Source    : String;
      Abandoned : in out Natural)
   is
      Chosen : Object := Raven.Objects.Nil;
      Clause : Object := Target.Cdr (Target.Top);
   begin
      --  Choosing makes nothing, so the clauses can be walked from an
      --  Ada variable.  What is chosen goes on the stack before anything
      --  is read, because reading a declaration runs the machine.

      while Raven.Objects.Is_Pair (Clause) loop
         declare
            This_Clause : constant Object := Target.Car (Clause);
         begin
            if Raven.Objects.Is_Pair (This_Clause)
              and then
                (Target.Car (This_Clause) = Target.To_Symbol ("else")
                 or else Requirement_Holds
                           (Target, Target.Car (This_Clause)))
            then
               Chosen := Target.Cdr (This_Clause);
               exit;
            end if;
         end;
         Clause := Target.Cdr (Clause);
      end loop;

      --  None holding and no else is left unspecified by R7RS, and here
      --  is nothing: the library is read without whatever the
      --  cond-expand would have given it.

      Target.Drop;
      Target.Push (Chosen);

      while Raven.Objects.Is_Pair (Target.Top) loop
         Target.Push (Target.Car (Target.Top));
         Read_Declaration (Target, Library, Directory, Source, Abandoned);
         Target.Push (Target.Cdr (Target.Pop));
      end loop;

      Target.Drop;
   end Read_Cond_Expand;

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
      elsif Is_Head (Target, "include")
        or else Is_Head (Target, "include-ci")
      then

         --  include-ci reads a file as though it began with #!fold-case,
         --  and every file already is read that way: the reader folds
         --  every identifier to lower case as it interns it.  So the two
         --  are one declaration here, until the reader stops folding.

         Read_Include (Target, Library, Directory, Abandoned);
      elsif Is_Head (Target, "cond-expand") then
         Read_Cond_Expand (Target, Library, Directory, Source, Abandoned);
      else

         --  Counted as a form that could not be run is, and for the same
         --  reason: the library would otherwise be read without whatever
         --  the declaration was to give it -- an export, an import, the
         --  right branch -- and be handed out as though it were whole.

         Abandon
           (Target, Source, Form_Head (Target),
            "not a library declaration", Abandoned);
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
      It : Object := Target.Cdr (Target.Top);
   begin
      --  A name, or (rename internal external).  Nothing here makes
      --  anything, so the list can be walked from an Ada variable.

      while Raven.Objects.Is_Pair (It) loop
         declare
            Spec : constant Object := Target.Car (It);
         begin
            if Raven.Objects.Is_Symbol (Spec) then
               Target.Add_Export
                 (Library, Target.To_String (Raven.Objects.To_Symbol (Spec)));
            elsif Is_Rename (Target, Spec) then
               Target.Add_Export
                 (Library,
                  Internal =>
                    Target.To_String
                      (Raven.Objects.To_Symbol (Target.Cadr (Spec))),
                  External =>
                    Target.To_String
                      (Raven.Objects.To_Symbol
                         (Target.Car (Target.Cddr (Spec)))));
            else
               Report
                 (Target,
                  "export: expected a name or (rename internal external),"
                  & " not " & Target.Show (Spec));
            end if;
         end;
         It := Target.Cdr (It);
      end loop;

      Target.Drop;
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
               Target.Reset_Dynamic_State;
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
               Target.Reset_Dynamic_State;
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
      Requests : Request_Vectors.Vector;
      It       : Object := Target.Cdr (Target.Top);
   begin
      --  Everything the declaration asks for is taken out of it before
      --  anything is loaded: loading runs the machine, and nothing
      --  here could hold a form across that.

      while Raven.Objects.Is_Pair (It) loop
         declare
            Spec    : constant Object := Target.Car (It);
            Request : Import_Request;
         begin
            if Raven.Objects.Is_Pair (Spec) then
               if Parse_Import_Set (Target, Spec, Request) then
                  Requests.Append (Request);
               end if;
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

      for Request of Requests loop
         declare
            Id    : constant Raven.Target.Library_Id :=
                      Load
                        (Target,
                         Ada.Strings.Unbounded.To_String (Request.Library));
            Names : String_Maps.Map;
         begin
            if Id = Raven.Target.No_Library then
               null;
            elsif Request.Steps.Is_Empty then
               Target.Add_Import (Library, Id);
            elsif Import_Set_Names (Target, Id, Request, Names) then
               Target.Begin_Mapped_Import (Library, Id);
               for Position in Names.Iterate loop
                  Target.Map_Import
                    (Library,
                     Local    => String_Maps.Key (Position),
                     External => String_Maps.Element (Position));
               end loop;
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

   -----------------------
   -- Requirement_Holds --
   -----------------------

   function Requirement_Holds
     (Target      : Raven.Target.Reference;
      Requirement : Object)
      return Boolean
   is
      use Raven.Objects;

      function Head_Is (Name : String) return Boolean
      is (Target.Car (Requirement) = Target.To_Symbol (Name));

      function All_Hold (List : Object) return Boolean;
      function Any_Holds (List : Object) return Boolean;

      --------------
      -- All_Hold --
      --------------

      function All_Hold (List : Object) return Boolean is
         It : Object := List;
      begin
         while Is_Pair (It) loop
            if not Requirement_Holds (Target, Target.Car (It)) then
               return False;
            end if;
            It := Target.Cdr (It);
         end loop;
         return True;
      end All_Hold;

      ---------------
      -- Any_Holds --
      ---------------

      function Any_Holds (List : Object) return Boolean is
         It : Object := List;
      begin
         while Is_Pair (It) loop
            if Requirement_Holds (Target, Target.Car (It)) then
               return True;
            end if;
            It := Target.Cdr (It);
         end loop;
         return False;
      end Any_Holds;

   begin
      if Is_Symbol (Requirement) then
         return Raven.Features.Is_Feature
           (Target.To_String (To_Symbol (Requirement)));
      elsif not Is_Pair (Requirement) then
         null;
      elsif Head_Is ("and") then
         return All_Hold (Target.Cdr (Requirement));
      elsif Head_Is ("or") then
         return Any_Holds (Target.Cdr (Requirement));
      elsif Head_Is ("not")
        and then Is_Pair (Target.Cdr (Requirement))
      then
         return not Requirement_Holds (Target, Target.Cadr (Requirement));
      elsif Head_Is ("library")
        and then Is_Pair (Target.Cdr (Requirement))
      then

         --  A library that is here, or one that could be read: which
         --  asks where it would be found and does not read it.

         declare
            Name : constant String :=
                     Library_Name (Target, Target.Cadr (Requirement));
         begin
            return Target.Library (Name) /= Raven.Target.No_Library
              or else Find_File (Target, Name) /= "";
         end;
      end if;

      Report
        (Target,
         "cond-expand: not a feature requirement: "
         & Target.Show (Requirement));
      return False;
   end Requirement_Holds;

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
