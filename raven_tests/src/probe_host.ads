--  A host that is not part of raven.
--
--  Every other suite here is a child of Raven and sees its private
--  part, so none of them can say whether the public interface is
--  enough to write a foreign value with.  This one is a root unit
--  like any embedding program, so it sees exactly what a host sees:
--  if anything it needs stops being public, this stops compiling.
--
--  What it defines is a pair of cells of its own -- a foreign value
--  holding two objects of the program's -- which is the case the
--  public interface exists for and the one that cannot be written
--  with handles, because Free is given no VM to release them with.

with Raven;

package Probe_Host is

   procedure Bind (VM : Raven.Raven_VM);

end Probe_Host;
