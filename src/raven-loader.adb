with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Raven.Objects;
with Raven.Parser;

package body Raven.Loader is

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

   function Is_Import
     (Target : Raven.Target.Reference)
      return Boolean;

   function Library_Name
     (Target : Raven.Target.Reference;
      Spec   : Object)
      return String;

   procedure Read_Imports
     (Target : Raven.Target.Reference;
      Names  : out String_Vectors.Vector);

   function Read_File (Path : String) return String;

   procedure Report (Message : String);

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

   ------------
   -- Import --
   ------------

   procedure Import
     (Target : Raven.Target.Reference;
      Name   : String;
      Path   : String)
   is
      use type Raven.Target.Library_Id;
      Library : constant Raven.Target.Library_Id :=
                  Load_File (Target, Name, Path);
   begin
      if Library /= Raven.Target.No_Library then
         Target.Add_Import (Target.Interaction_Library, Library);
      end if;
   end Import;

   ---------------
   -- Is_Import --
   ---------------

   function Is_Import
     (Target : Raven.Target.Reference)
      return Boolean
   is
      Form : constant Object := Target.Top;
   begin
      return Raven.Objects.Is_Pair (Form)
        and then Target.Car (Form) = Target.To_Symbol ("import");
   end Is_Import;

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
      use type Raven.Target.Library_Id;
      Loaded : constant Raven.Target.Library_Id := Target.Library (Name);
   begin
      if Loading.Contains (Name) then
         Report ("import: " & Name & " imports itself");
         return Loaded;
      elsif Loaded /= Raven.Target.No_Library then
         return Loaded;
      end if;

      declare
         Path : constant String := Find_File (Target, Name);
      begin
         if Path = "" then
            Report ("import: no library " & Name);
            return Raven.Target.No_Library;
         end if;
         return Load_File (Target, Name, Path);
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
      use type Raven.Target.Library_Id;
      Found   : constant Raven.Target.Library_Id := Target.Library (Name);
      Library : constant Raven.Target.Real_Library_Id :=
                  (if Found = Raven.Target.No_Library
                   then Target.Create_Library (Name)
                   else Found);
   begin
      Loading.Append (Name);

      declare
         Source : constant String := Read_File (Path);
         Reader : Raven.Parser.Instance;
      begin
         Reader.Open (Name, Source);

         while not Reader.At_End loop

            --  A form that names something undefined is reported and
            --  the rest of the file is read anyway.  Anything else
            --  stops the load, and is reported by the handler below.

            begin
               Reader.Parse_Next (Target);

               if Is_Import (Target) then
                  declare
                     Names : String_Vectors.Vector;
                  begin
                     --  Everything the declaration asks for is taken
                     --  out of it before anything is loaded: loading
                     --  runs the machine, and nothing here could hold
                     --  an object across that.

                     Read_Imports (Target, Names);
                     Target.Drop;

                     for Imported of Names loop
                        declare
                           Id : constant Raven.Target.Library_Id :=
                                  Load (Target, Imported);
                        begin
                           if Id /= Raven.Target.No_Library then
                              Target.Add_Import (Library, Id);
                           end if;
                        end;
                     end loop;
                  end;
               else
                  Target.Translate (Library);
                  Target.Execute;
                  Target.Drop;
               end if;
            exception
               when E : Raven.Target.Undefined_Symbol =>
                  Report ("undefined: " & Ada.Exceptions.Exception_Message (E));
            end;
         end loop;

         Reader.Close;
      end;

      Loading.Delete_Last;
      return Library;

   exception
      when E : others =>
         Report (Name & ": " & Ada.Exceptions.Exception_Message (E));
         if not Loading.Is_Empty then
            Loading.Delete_Last;
         end if;
         return Library;
   end Load_File;

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

   ------------------
   -- Read_Imports --
   ------------------

   procedure Read_Imports
     (Target : Raven.Target.Reference;
      Names  : out String_Vectors.Vector)
   is
      It : Object := Target.Cdr (Target.Top);
   begin
      Names.Clear;
      while Raven.Objects.Is_Pair (It) loop
         declare
            Spec : constant Object := Target.Car (It);
         begin
            if Raven.Objects.Is_Pair (Spec) then
               Names.Append (Library_Name (Target, Spec));
            else
               Report
                 ("import: a library name is a list, not "
                  & Target.Show (Spec));
            end if;
         end;
         It := Target.Cdr (It);
      end loop;
   end Read_Imports;

   ------------
   -- Report --
   ------------

   procedure Report (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Report;

end Raven.Loader;
