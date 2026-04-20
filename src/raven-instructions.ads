private package Raven.Instructions is

   type Instruction is
     (LD, LDC, LDF, AP, RTN, DUM, RAP, SEL, JOIN,
      CAR, CDR, CONS, APPEND, EQ,
      DROP, NIL, IS_NULL, ATOM, PAIR,
      OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_REM, OP_LEQ,
      DFN, ST,
      STOP, NOP);

end Raven.Instructions;
