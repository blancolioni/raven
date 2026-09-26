--  What a slot holds, and asking before taking.
--
--  A foreign function is handed its arguments in slots and had no way
--  to find out what was in one.  Raven's own primitives ask
--  Raven.Objects, which a host cannot reach; a host could only call a
--  getter and hope.

private package Raven.Tests.Slots is

   procedure Run_Tests (VM : Raven_VM);

end Raven.Tests.Slots;
