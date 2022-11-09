This manual is a addition to the readme.md and tells the typical using of the biosim binary.

## Starting the application:
 biosim accepts 2 different ways of starting
 
### Start by using a .ini file
This is the typical usecase.<br>

  example: "biosim biosim4.ini" <br>

The simulation will be executed using the definitions from biosim4.ini

### Start by using a .sim file
When regular shutting down, the biosim application always stores a .sim file named after the .ini file that was passed on the first start. By using the .sim file as argument it is possible to continue the simulation from the situation as it was at the end of the last simulation. The "linked" .ini file will be read in fresh, so it is possible to stop a endless simulation by pressing ESC during execution, change some parameters in the corresponding .ini file and continue the simulation at a later point.<br>
!! Attention !! <br>
The epoch log file will not be specially saved. So secure that it will not be overwriten by other simulations.<br>

  example: "biosim biosim4.sim" <br>

## Key commands during execution
ESC - abort the simulation (after simulation of one last generation, that will write a last video if video feature is enabled) <br>
q - abort video creation during shutdown process<br>
v - create a video of the next simulated generation (no matter if videostride feature is enabled or not)