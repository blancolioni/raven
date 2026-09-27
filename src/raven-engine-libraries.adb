with Raven.Engine.Environment;

package body Raven.Engine.Libraries is

   --  What a library offers an importer, which is not what it holds:
   --  a name it keeps to itself is in neither of these answers.

   function Provides
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean;

   ----------------
   -- Add_Export --
   ----------------

   procedure Add_Export
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Exports.Include (Name);
   end Add_Export;

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

   -----------
   -- Binds --
   -----------

   function Binds
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      if Entry_Of.Defined.Contains (Name)
        or else Entry_Of.Macros.Contains (Name)
      then
         return True;
      end if;

      for Imported of Entry_Of.Imports loop
         if This.Provides (Imported, Name) then
            return True;
         end if;
      end loop;

      return False;
   end Binds;

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

   ------------------
   -- Define_Macro --
   ------------------

   procedure Define_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String;
      Id      : Raven.Target.Real_Macro_Id)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Macros.Include (Name, Id);
   end Define_Macro;

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

   -----------
   -- Macro --
   -----------

   function Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id
   is
      Entry_Of : Library_Record renames This.Table (Library);
      Position : constant Macro_Maps.Cursor := Entry_Of.Macros.Find (Name);
   begin
      if Macro_Maps.Has_Element (Position) then
         return Macro_Maps.Element (Position);
      elsif Entry_Of.Defined.Contains (Name) then
         return Raven.Target.No_Macro;
      end if;

      for Imported of reverse Entry_Of.Imports loop
         declare
            Found : constant Macro_Maps.Cursor :=
                      This.Table (Imported).Macros.Find (Name);
         begin
            if Macro_Maps.Has_Element (Found)
              and then This.Provides (Imported, Name)
            then
               return Macro_Maps.Element (Found);
            end if;
         end;
      end loop;

      return Raven.Target.No_Macro;
   end Macro;

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

   ---------------
   -- Own_Macro --
   ---------------

   function Own_Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id
   is
      Position : constant Macro_Maps.Cursor :=
                   This.Table (Library).Macros.Find (Name);
   begin
      if Macro_Maps.Has_Element (Position) then
         return Macro_Maps.Element (Position);
      else
         return Raven.Target.No_Macro;
      end if;
   end Own_Macro;

   --------------
   -- Provides --
   --------------

   function Provides
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      if Entry_Of.Exports_All then
         return Entry_Of.Defined.Contains (Name)
           or else Entry_Of.Macros.Contains (Name);
      else
         return Entry_Of.Exports.Contains (Name);
      end if;
   end Provides;

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
         if This.Provides (Imported, Name) then
            return Imported;
         end if;
      end loop;

      return Library;
   end Resolve;

   ---------------------
   -- Set_Export_List --
   ---------------------

   procedure Set_Export_List
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Exports_All := False;
   end Set_Export_List;

   --------------------
   -- Undefine_Macro --
   --------------------

   procedure Undefine_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Macros.Exclude (Name);
   end Undefine_Macro;

end Raven.Engine.Libraries;
