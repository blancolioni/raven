private package Raven.Instructions is

   --  TAP and TSEL are the tail forms of AP and SEL.  What tells them
   --  apart from the other two is only what they do not do: neither
   --  saves anything on the dump, because in tail position there is
   --  nothing left to come back to.

   type Instruction is
     (LD, LDC, LDF, AP, TAP, RTN, DUM, RAP, SEL, TSEL, JOIN,
      CAR, CDR, CONS, APPEND, EQ,
      DROP, NIL, IS_NULL, ATOM, PAIR,
      OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_REM, OP_LEQ,
      DFN, ST,
      STOP, NOP);

end Raven.Instructions;
