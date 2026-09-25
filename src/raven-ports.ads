with Raven.Evaluator;

private package Raven.Ports is

   --  A port is a foreign value, the way a string is, and holds an id
   --  into a table of what the port is and where it has got to.  It
   --  is in a table rather than in the value because a port is read
   --  and written through and so changes, and a foreign value is
   --  handed out by copy.
   --
   --  Which is what Free is for, and why it had to start being
   --  called: the collector deleted a value that was no longer named
   --  and never told it, so a port's entry would have stayed for the
   --  rest of the session.
   --
   --  Three ports are the host's -- what it writes, what it writes
   --  errors to, and what it reads -- and have places in the table
   --  kept for them, so that asking for one twice is asking for the
   --  same port and not making another.  The rest are strings: one
   --  being read out of, or one being built up.

   procedure Load_Port_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class);

end Raven.Ports;
