with Raven.Engine.Environment;

package body Raven.Engine.Libraries is

   --  What a library offers an importer, which is not what it holds:
   --  a name it keeps to itself is in neither of these answers.

   function Provides
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean;

   --  Whether an import gives this library Name, and what the imported
   --  library exports it as when it does.

   function Import_Gives
     (This    : Instance;
      Import  : Import_Entry;
      Name    : String)
      return Boolean;

   function Exported_As
     (Import : Import_Entry;
      Name   : String)
      return String
   is (if Import.Mapped then Import.Names.Element (Name) else Name);

   --  Where Name, written in Library, is defined, and what it is called
   --  there (#140).  An import that gives a name the library does not
   --  define is followed into the library that offers it, and on from
   --  there, because a library may offer what it imported: the end of
   --  the walk is a library that defines the name, or one that nothing
   --  it imports accounts for, which is where the name will be looked
   --  for if it is ever defined.
   --
   --  Libraries may import each other, so a walk that goes on longer
   --  than there are libraries has gone round.  That is Found False:
   --  nothing accounts for the name.

   procedure Trace
     (This      : Instance;
      Library   : Raven.Target.Real_Library_Id;
      Name      : String;
      Depth     : Natural;
      Found     : out Boolean;
      Home      : out Raven.Target.Real_Library_Id;
      Home_Name : out Unbounded_String);

   --  What a library that provides Name calls it.

   function Internal_Name
     (This     : Instance;
      Library  : Raven.Target.Real_Library_Id;
      External : String)
      return String
     with Pre => This.Provides (Library, External);

   ----------------
   -- Add_Export --
   ----------------

   procedure Add_Export
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
   begin
      This.Add_Export (Library, Name, Name);
   end Add_Export;

   ----------------
   -- Add_Export --
   ----------------

   procedure Add_Export
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Internal : String;
      External : String)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      --  The last export of a name is the one it means, as the last
      --  import of one is.

      Entry_Of.Exports.Include (External, Internal);
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
   begin
      --  Imported again is imported once, and last: the most recent
      --  import of a name is the one it means.  Only a plain import of
      --  the same library is the same import; an import set of it is
      --  another, and both stand.

      for Index in reverse
        Entry_Of.Imports.First_Index .. Entry_Of.Imports.Last_Index
      loop
         declare
            Import : constant Import_Entry := Entry_Of.Imports (Index);
         begin
            if Raven.Target."=" (Import.Library, Imported)
              and then not Import.Mapped
            then
               Entry_Of.Imports.Delete (Index);
            end if;
         end;
      end loop;

      Entry_Of.Imports.Append
        (Import_Entry'(Library => Imported, others => <>));
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

   -------------------------
   -- Begin_Mapped_Import --
   -------------------------

   procedure Begin_Mapped_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
   begin
      Entry_Of.Imports.Append
        (Import_Entry'(Library => Imported, Mapped => True, Names => <>));
   end Begin_Mapped_Import;

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

      for Import of Entry_Of.Imports loop
         if This.Import_Gives (Import, Name) then
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

   ------------------
   -- Import_Gives --
   ------------------

   function Import_Gives
     (This    : Instance;
      Import  : Import_Entry;
      Name    : String)
      return Boolean
   is (if Import.Mapped
       then Import.Names.Contains (Name)
            and then This.Provides (Import.Library, Import.Names (Name))
       else This.Provides (Import.Library, Name));

   -------------------
   -- Internal_Name --
   -------------------

   function Internal_Name
     (This     : Instance;
      Library  : Raven.Target.Real_Library_Id;
      External : String)
      return String
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      if Entry_Of.Exports_All then
         return External;
      else
         return Entry_Of.Exports.Element (External);
      end if;
   end Internal_Name;

   ---------------------
   -- Iterate_Exports --
   ---------------------

   procedure Iterate_Exports
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Process : not null access procedure (Name : String))
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      if Entry_Of.Exports_All then
         for Name of Entry_Of.Defined loop
            Process (Name);
         end loop;

         for Position in Entry_Of.Macros.Iterate loop
            if not Entry_Of.Defined.Contains (Macro_Maps.Key (Position)) then
               Process (Macro_Maps.Key (Position));
            end if;
         end loop;
      else
         for Position in Entry_Of.Exports.Iterate loop
            Process (Name_Maps.Key (Position));
         end loop;
      end if;
   end Iterate_Exports;

   -----------
   -- Macro --
   -----------

   function Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id
   is
      Found     : Boolean;
      Home      : Raven.Target.Real_Library_Id;
      Home_Name : Unbounded_String;
   begin
      This.Trace
        (Library, Name, Natural (This.Table.Length),
         Found, Home, Home_Name);

      if Found then
         declare
            Position : constant Macro_Maps.Cursor :=
                         This.Table (Home).Macros.Find (To_String (Home_Name));
         begin
            if Macro_Maps.Has_Element (Position) then
               return Macro_Maps.Element (Position);
            end if;
         end;
      end if;

      return Raven.Target.No_Macro;
   end Macro;

   ----------------
   -- Map_Import --
   ----------------

   procedure Map_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Local    : String;
      External : String)
   is
      Entry_Of : constant Library_Vectors.Reference_Type :=
                   This.Table.Reference (Library);
      Last     : constant Import_Vectors.Reference_Type :=
                   Entry_Of.Imports.Reference (Entry_Of.Imports.Last);
   begin
      Last.Names.Include (Local, External);
   end Map_Import;

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
      Found     : Boolean;
      Home      : Raven.Target.Real_Library_Id;
      Home_Name : Unbounded_String;
   begin
      This.Trace
        (Library, Name, Natural (This.Table.Length),
         Found, Home, Home_Name);
      return (if Found then Home else Library);
   end Resolve;

   -------------------
   -- Resolved_Name --
   -------------------

   function Resolved_Name
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return String
   is
      Found     : Boolean;
      Home      : Raven.Target.Real_Library_Id;
      Home_Name : Unbounded_String;
   begin
      --  The same walk as Resolve, answering with the other half.

      This.Trace
        (Library, Name, Natural (This.Table.Length),
         Found, Home, Home_Name);
      return (if Found then To_String (Home_Name) else Name);
   end Resolved_Name;

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

   -----------
   -- Trace --
   -----------

   procedure Trace
     (This      : Instance;
      Library   : Raven.Target.Real_Library_Id;
      Name      : String;
      Depth     : Natural;
      Found     : out Boolean;
      Home      : out Raven.Target.Real_Library_Id;
      Home_Name : out Unbounded_String)
   is
      Entry_Of : Library_Record renames This.Table (Library);
   begin
      Found := True;
      Home := Library;
      Home_Name := To_Unbounded_String (Name);

      if Entry_Of.Defined.Contains (Name)
        or else Entry_Of.Macros.Contains (Name)
      then
         return;
      end if;

      --  The most recent import of a name is the one it means.

      for Import of reverse Entry_Of.Imports loop
         if This.Import_Gives (Import, Name) then
            if Depth = 0 then
               Found := False;
            else
               This.Trace
                 (Import.Library,
                  This.Internal_Name
                    (Import.Library, Exported_As (Import, Name)),
                  Depth - 1, Found, Home, Home_Name);
            end if;
            return;
         end if;
      end loop;
   end Trace;

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
