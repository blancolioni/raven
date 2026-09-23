with Ada.Strings.Equal_Case_Insensitive;
with Raven.Engine.Environment;

package body Raven.Engine.Libraries is

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
      --  table entry that keeps it.

      This.Table.Append
        (Library_Record'
           (Name        => To_Unbounded_String (Name),
            Environment => Raven.Engine.Environment.Create (Parent)));
      return This.Table.Last_Index;
   end Create;

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

end Raven.Engine.Libraries;
