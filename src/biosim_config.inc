(*
 * Following are some Features selectable by compiler switch
 * main reason to do so is performance, so be carefull when changing settings
 *)

(*
  Choosing the right Sigmoid function is a bit tricky, the code sopports different ones:
  the numbers in the brackets are the runtimes of deterministic0.ini on a reference machine.
  => Changing the sigmoid function definitly changes results so choose wise.

1. SigmoidTanh (2:53min):
  - Mathematically correct, but damn fucking slow
2. SigmoidTable (1:14min):
  - Mathematically correct, but discrete sampled -> not ideal but the fastest !
3. SigmoidXdix1plusX (1:36min):
  - a common used sigmoid function -> fast but 10% worse than SigmoidTanh
4. SigmoidApprox (1:46min):
  - at max 2.3% worse in accurancy but fast -> results are better than SigmoidTanh
*)

{.$DEFINE SigmoidTanh}
{.$DEFINE SigmoidTable}
{.$DEFINE SigmoidXdix1plusX}
{$DEFINE SigmoidApprox}

(*
 * Enable / Disable "Actions" evaluation in .ini file
 * Enabling this feature will increase calculation time of e.g. deterministic0.ini by ~8s
 *)

{.$DEFINE EvalActionEnables}

(*
 * Enable / Disable "Sensors" evaluation in .ini file
 * Enabling this feature will increase calculation time of e.g. deterministic0.ini by ~6s
 *)

{.$DEFINE EvalSensorsEnables}

