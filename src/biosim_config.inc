(*
 * Following are some Features selectable by compiler switch
 * main reason to do so is performance, so be carefull when changing settings
 *)

(*
  Choosing the right Sigmoid function is a bit tricky, the code supports different kinds:
  the numbers in the brackets are the runtimes of deterministic0.ini on a reference machine.
  => Changing the sigmoid function definitly changes results so choose wise.

1. SigmoidTable (1:14min):
  - Mathematically correct, but discrete sampled -> not ideal but the fastest !

2. SigmoidXdix1plusX (1:36min):
  - a common used sigmoid function -> fast but 10% worse than SigmoidTanh

3. SigmoidApprox (1:46min):
  - at max 2.3% worse in accurancy but fast -> results are better than SigmoidTanh

4. SigmoidTanh (2:53min):
  - Mathematically correct, but damn fucking slow
*)

{.$DEFINE SigmoidTable}
{.$DEFINE SigmoidXdix1plusX}
{$DEFINE SigmoidApprox}
{.$DEFINE SigmoidTanh}

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
