with Ada.Text_IO;

with Raven.Engine.Environment;
with Raven.Engine.Memory;
with Raven.Engine.SECD;
with Raven.Engine.SECD.Tests;
with Raven.Engine.SECD.Translator;
with Raven.Engine.Symbols;
with Raven.Environment;
with Raven.Memory;
with Raven.Objects;
with Raven.Symbols;
with Raven.Target;
with Raven.Translator;

package body Raven.Engine.Tests is

   procedure Test
     (Target   : Raven.Target.Reference;
      Name     : String;
      Source   : Object;
      Expected : Integer);

   procedure Test
     (Name     : String;
      Success  : Boolean);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
      use Raven.Objects;
      Memory : constant Raven.Memory.Reference :=
                 Raven.Engine.Memory.Create
                   (1024);
      Env    : constant Raven.Environment.Reference :=
                 Raven.Engine.Environment.Create;
      Syms   : constant Raven.Symbols.Reference :=
                 Raven.Engine.Symbols.Create;
      Target : constant Raven.Target.Reference :=
                 Raven.Engine.SECD.Create (VM, Memory, Env, Syms);
   begin
      Test (Target, "integer literal translation",
            To_Object (Integer'(1453)), 1453);
      Raven.Engine.SECD.Tests.Run_Tests (Target);
      Memory.Report;
   end Run_Tests;

   ----------
   -- Test --
   ----------

   procedure Test
     (Target   : Raven.Target.Reference;
      Name     : String;
      Source   : Object;
      Expected : Integer)
   is
      use Raven.Objects;
      Translator : Raven.Translator.Abstraction'Class :=
                     Raven.Engine.SECD.Translator.Create;
   begin
      Target.Push (Source);
      Translator.Translate (Target);
      Target.Execute;
      declare
         Result : constant Object := Target.Pop;
      begin
         Test (Name,
               Is_Integer (Result)
               and then To_Integer (Result) = Expected);
      end;
   end Test;

   ----------
   -- Test --
   ----------

   procedure Test
     (Name     : String;
      Success  : Boolean)
   is
      use Ada.Text_IO;
   begin
      Put (Name);
      Set_Col (74);
      Put (if Success then "PASS" else "FAIL");
      New_Line;
   end Test;

end Raven.Engine.Tests;
