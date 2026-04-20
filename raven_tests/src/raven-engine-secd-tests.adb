with Ada.Exceptions;
with Ada.Text_IO;

with Raven.Instructions;               use Raven.Instructions;
with Raven.Objects;

package body Raven.Engine.SECD.Tests is

   package Object_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Object);

   function Int (X : Integer) return Object
                 renames Raven.Objects.To_Object;

   function Op (X : Instruction) return Object
                renames Raven.Objects.To_Object;

   procedure Test
     (Target   : Raven.Target.Reference;
      Name     : String;
      Code     : Object_Lists.List;
      Expected : Object);

   type Object_List_Array is array (Positive range <>) of Object_Lists.List;

   procedure Test_Nested
     (Target   : Raven.Target.Reference;
      Name     : String;
      Code     : Object_List_Array;
      Expected : Object);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests
     (Target : Raven.Target.Reference)
   is
   begin
      Test (Target, "integer addition",
            [Op (LDC), Int (21), Op (LDC), Int (17),
             Op (OP_ADD), Op (STOP)],
            Int (38));
      Test (Target, "integer comparison",
            [Op (LDC), Int (21), Op (LDC), Int (17),
             Op (OP_LEQ), Op (STOP)],
            Objects.To_Object (False));
      Test (Target, "integer equality",
            [Op (LDC), Int (21), Op (LDC), Int (21),
             Op (EQ), Op (STOP)],
            Objects.To_Object (True));
      Test (Target, "integer inequality",
            [Op (LDC), Int (3), Op (LDC), Int (21),
             Op (EQ), Op (STOP)],
            Objects.To_Object (False));
      Test (Target, "car",
            [Op (LDC), Int (3), Op (LDC), Int (21), Op (CONS),
             Op (CAR), Op (STOP)],
            Int (21));
      Test (Target, "cdr",
            [Op (LDC), Int (3), Op (LDC), Int (21), Op (CONS),
             Op (CDR), Op (STOP)],
            Int (3));
      Test_Nested
        (Target,
         "simple sel/join",
         [
              [Op (LDC), Int (1), Op (SEL),
               Objects.Undefined, Objects.Undefined,
               Op (STOP)],
          [Op (LDC), Int (42), Op (JOIN)],
          [Op (LDC), Int (37), Op (JOIN)]
         ],
         Int (42));

      Test_Nested
        (Target,
         "sel/join",
         [
              [Op (LDC), Int (1),
               Op (LDC), Int (19),
               Op (EQ),
               Op (SEL),
               Objects.Undefined, Objects.Undefined,
               Op (STOP)],
          [Op (LDC), Int (42), Op (JOIN)],
          [Op (LDC), Int (37), Op (JOIN)]
         ],
         Int (37));

   end Run_Tests;

   ----------
   -- Test --
   ----------

   procedure Test
     (Target   : Raven.Target.Reference;
      Name     : String;
      Code     : Object_Lists.List;
      Expected : Object)
   is
   begin
      for Item of Code loop
         Target.Push (Item);
      end loop;
      Target.Push (Objects.Nil);
      for Item of Code loop
         Target.Cons;
      end loop;
      Target.Execute;
      declare
         use Ada.Text_IO;
         Result : constant Object := Target.Pop;
         Success : constant Boolean := Result = Expected;
      begin
         Put (Name);
         Set_Col (74);
         Put (if Success then "PASS" else "FAIL");
         New_Line;
      end;
   exception
      when E : others =>
         Ada.Text_IO.Put (Name);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
   end Test;

   -----------------
   -- Test_Nested --
   -----------------

   procedure Test_Nested
     (Target   : Raven.Target.Reference;
      Name     : String;
      Code     : Object_List_Array;
      Expected : Object)
   is
      Next_Index : Positive := Code'First;

      procedure Create (List : Object_Lists.List);

      ------------
      -- Create --
      ------------

      procedure Create (List : Object_Lists.List) is
      begin
         for Item of List loop
            if Item = Objects.Undefined then
               Next_Index := Next_Index + 1;
               Create (Code (Next_Index));
            else
               Target.Push (Item);
            end if;
         end loop;
         Target.Push (Objects.Nil);
         for Item of List loop
            Target.Cons;
         end loop;
      end Create;

   begin
      Create (Code (Next_Index));
      Target.Execute;
      declare
         use Ada.Text_IO;
         Result : constant Object := Target.Pop;
         Success : constant Boolean := Result = Expected;
      begin
         Put (Name);
         Set_Col (74);
         Put (if Success then "PASS" else "FAIL");
         New_Line;
      end;
   exception
      when E : others =>
         Ada.Text_IO.Put (Name);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
   end Test_Nested;

end Raven.Engine.SECD.Tests;
