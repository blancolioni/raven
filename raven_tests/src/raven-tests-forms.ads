--  Every special form asked what shape it takes before taking it.
--
--  They used to take it apart and find out afterwards: (define) asked
--  for the car of nil, which is a precondition on Raven.Pairs, so a
--  badly written program was told Assertion_Error out of the machine
--  and nothing whatever about the form.

private package Raven.Tests.Forms is

   procedure Run_Tests;

end Raven.Tests.Forms;
