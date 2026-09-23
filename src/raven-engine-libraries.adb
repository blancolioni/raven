with Ada.Strings.Equal_Case_Insensitive;
with Raven.Engine.Environment;

package body Raven.Engine.Libraries is

   ----------------
   -- Add_Import --
   ----------------

   procedure Add_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
      Already  : constant Import_Vectors.Extended_Index :=
                   Entry_Of.Imports.Find_Index (Imported);
   begin
      --  Imported again is imported once, and last: the most recent
      --  import of a name is the one it means.

      if Already /= Import_Vectors.No_Index then
         Entry_Of.Imports.Delete (Already);
      end if;

      Entry_Of.Imports.Append (Imported);
   end Add_Import;

   --------------
   -- Add_Path --
   --------------

   procedure Add_Path
     (This : in out Instance;
      Path : String)
   is
   begin
      This.Paths.Append (Path);
   end Add_Path;

   ------------
   -- Create --
   ------------

   function Create
     (This   : in out Instance;
      Name   : String;
      Parent : Raven.Environment.Reference)
      return Raven.Target.Real_Library_Id
   is
   begin
      --  Creating an environment allocates nothing the collector
      --  walks, so there is no moment between the environment and the
      --  table entry that would have to keep it.

      This.Table.Append
        (Library_Record'
           (Name        => To_Unbounded_String (Name),
            Environment => Raven.Engine.Environment.Create (Parent),
            others      => <>));
      return This.Table.Last_Index;
   end Create;

   -----------------
   -- Define_Name --
   -----------------

   procedure Define_Name
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Defined.Include (Name);
   end Define_Name;

   ----------
   -- Find --
   ----------

   function Find
     (This : Instance;
      Name : String)
      return Raven.Target.Library_Id
   is
   begin
      for Id in 1 .. This.Table.Last_Index loop
         if Ada.Strings.Equal_Case_Insensitive
           (To_String (This.Table (Id).Name), Name)
         then
            return Id;
         end if;
      end loop;
      return Raven.Target.No_Library;
   end Find;

   ----------
   -- Mark --
   ----------

   procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      for Library of This.Table loop
         Library.Environment.Mark (Process);
      end loop;
   end Mark;

   -------------
   -- Resolve --
   -------------

   function Resolve
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Real_Library_Id
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      if Entry_Of.Defined.Contains (Name) then
         return Library;
      end if;

      for Imported of reverse Entry_Of.Imports loop
         if This.Table (Imported).Defined.Contains (Name) then
            return Imported;
         end if;
      end loop;

      return Library;
   end Resolve;

end Raven.Engine.Libraries;
