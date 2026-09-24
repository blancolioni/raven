with Ada.Command_Line;
with Ada.Text_IO;

with Raven.Tests;

procedure Raven_Tests is
begin
   Raven.Tests.Run_Tests;

   --  The tests said what they found as they went and the program
   --  exited successfully whatever that was, so nothing but a person
   --  reading the output could tell.  A build on a server reads the
   --  exit status instead.

   if Raven.Tests.Failures > 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed:" & Raven.Tests.Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Raven_Tests;
