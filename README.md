# biosim4_FPC_translation

## Why this fork?

At the starting this fork was a 1:1 crosscompilation from the origin C++ version to FreePascal 
(using the Lazarus IDE). Beside the advantage of having a crossplattform codebase i mainly did
this for the purpose of learning C++ Code and beeing able to adjust the simulation for my own 
needs in my most favourite programming language.

Even if the complete codebase is writen by me I realised this as fork as i truly want to point 
out who the real inventor of this program is.


## What is this?

This pile of code was used to simulate biological creatures that evolve through natural selection.
The results of the experiments are summarized in this YouTube video:

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"I programmed some creatures. They evolved."

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;https://www.youtube.com/watch?v=N3tRFayqVtk

This code lacks a friendly interface, so compiling and executing the program may
require attention to details. If you ask questions in the Issues,
I'll try to help if I can.

Document Contents
-----------------

- [biosim4\_FPC\_translation](#biosim4_fpc_translation)
  - [Why this fork?](#why-this-fork)
  - [What is this?](#what-is-this)
  - [Document Contents](#document-contents)
  - [Code walkthrough](#code-walkthrough)
    - [Main data structures](#main-data-structures)
    - [Config file](#config-file)
    - [Program output](#program-output)
    - [Main program loop](#main-program-loop)
    - [Sensory inputs and action outputs](#sensory-inputs-and-action-outputs)
    - [Basic value types](#basic-value-types)
    - [Pheromones](#pheromones)
    - [Useful utility functions](#useful-utility-functions)
  - [Installing the code](#installing-the-code)
  - [Building the executable](#building-the-executable)
    - [System requirements](#system-requirements)
    - [Compiling](#compiling)
      - [Using the Lazarus-IDE](#using-the-lazarus-ide)
      - [via console](#via-console)
  - [Execution](#execution)
  - [Build log](#build-log)


Code walkthrough<a name="CodeWalkthrough"></a>
--------------------

<a name="MainDataStructures"></a>
### Main data structures

The code in the src directory compiles to a single console program named biosim4. When it is
invoked, it will read parameters from a config file named biosim4.ini by default. A different
config file can be specified on the command line.

The simulator will then configure a 2D arena where the creatures live. Class Grid (see grid.h and grid.cpp)
contains a 2D array of 16-bit indexes, where each nonzero index refers to a specific individual in class Peeps (see below).
Zero values in Grid indicate empty locations. Class Grid does not know anything else about the world; it only
stores indexes to represent who lives where.

The population of creatures is stored in class Peeps (see peeps.h and peeps.cpp). Class Peeps contains
all the individuals in the simulation, stored as instances of struct Indiv in a std::vector container.
The indexes in class Grid are indexes into the vector of individuals in class Peeps. Class Peeps keeps a
container of struct Indiv, but otherwise does not know anything about the internal workings of individuals.

Each individual is represented by an instance of struct Indiv (see indiv.h and indiv.cpp). Struct Indiv
contains an individual's genome, its corresponding neural net brain, and a redundant copy of the individual's
X,Y location in the 2D grid. It also contains a few other parameters for the individual, such as its
"responsiveness" level, oscillator period, age, and other personal parameters. Struct Indiv knows how
to convert an individual's genome into its neural net brain at the beginning of the simulation.
It also knows how to print the genome and neural net brain in text format to stdout during a simulation.
It also has a function Indiv::getSensor() that is called to compute the individual's input neurons for
each simulator step.

All the simulator code lives in the BS namespace (short for "biosim".)

<a name="ConfigFile"></a>
### Config file

The config file, named biosim4.ini by default, contains all the tunable parameters for a
simulation run. The biosim4 executable reads the config file at startup, then monitors it for
changes during the simulation. Although it's not foolproof, many parameters can be modified during
the simulation run. Class ParamManager (see params.h and params.cpp) manages the configuration
parameters and makes them available to the simulator through a read-only pointer provided by
ParamManager::getParamRef().

See the provided biosim4.ini for documentation for each parameter. Most of the parameters
in the config file correspond to members in struct Params (see params.h). A few additional
parameters may be stored in struct Params. See the documentation in params.h for how to
support new parameters.


<a name="ProgramOutput"></a>
### Program output

Depending on the parameters in the config file, the following data can be produced:

* The simulator will append one line to logs/epoch.txt after the completion of
each generation. Each line records the generation number, number of individuals
who survived the selection criterion, an estimate of the population's genetic
diversity, average genome length, and number of deaths due to the "kill" gene.
This file can be fed to tools/graphlog.gp to produce a graphic plot.

* The simulator will display a small number of sample genomes at regular
intervals to stdout. Parameters in the config file specify the number and interval.
The genomes are displayed in hex format and also in a mnemonic format that can
be fed to tools/graph-nnet.py to produce a graphic network diagram.

* Movies of selected generations will be created in the images/ directory. Parameters
in the config file specify the interval at which to make movies. Each movie records
a single generation.

* At intervals, a summary is printed to stdout showing the total number of neural
connections throughout the population from each possible sensory input neuron and to each
possible action output neuron.

<a name="MainProgramLoop"></a>
### Main program loop

The simulator starts with a call to simulator() in simulator.cpp. After initializing the
world, the simulator executes three nested loops: the outer loop for each generation,
an inner loop for each simulator step within the generation, and an innermost loop for
each individual in the population. The innermost loop is thread-safe so that it can
be parallelized by OpenMP.

At the end of each simulator step, a call is made to endOfSimStep() in single-thread
mode (see endOfSimStep.cpp) to create a video frame representing the locations of all
the individuals at the end of the simulator step. The video frame is pushed on to a
stack to be converted to a movie later. Also some housekeeping may be done for certain
selection scenarios.  See the comments in endOfSimStep.cpp for more information.

At the end of each generation, a call is made to endOfGeneration() in single-thread
mode (see endOfGeneration.cpp) to create a video from the saved video frames.
Also a new graph might be generated showing the progress of the simulation. See
endOfGeneraton.cpp for more information.

<a name="SensoryInputsAndActionOutputs"></a>
### Sensory inputs and action outputs

See the YouTube video (link above) for a description of the sensory inputs and action
outputs. Each sensory input and each action output is a neuron in the individual's
neural net brain.

The header file sensors-actions.h contains enum Sensor which enumerates all the possible sensory
inputs and enum Action which enumerates all the possible action outputs.
In enum Sensor, all the sensory inputs before the enumerant NUM_SENSES will
be compiled into the executable, and all action outputs before NUM_ACTIONS
will be compiled. By rearranging the enumerants in those enums, you can select
a subset of all possible sensory and action neurons to be compiled into the
simulator.

<a name="BasicValueTypes"></a>
### Basic value types

There are a few basic value types:

* enum Compass represents eight-way directions with enumerants N=0, NE, E, SW, S, SW, W, NW, CENTER.

* struct Dir is an abstract representation of the values of enum Compass.

* struct Coord is a signed 16-bit integer X,Y coordinate pair. It is used to represent a location
in the 2D world, or can represent the difference between two locations.

* struct Polar holds a signed 32-bit integer magnitude and a direction of type Dir.

Various conversions and math are possible between these basic types. See unitTestBasicTypes.cpp
for examples. Also see basicTypes.h for more information.

<a name="Pheromones"></a>
### Pheromones

A simple system is used to simulate pheromones emitted by the individuals. Pheromones
are called "signals" in simulator-speak (see signals.h and signals.cpp). Struct Signals
holds a single layer that overlays the 2D world in class Grid. Each location can contain
a level of pheromone (there's only a single kind of pheromone supported at present). The
pheromone level at any grid location is stored as an unsigned 8-bit integer, where zero means no
pheromone, and 255 is the maximum. Each time an individual emits a pheromone, it increases
the pheromone values in a small neighborhood around the individual up to the maximum
value of 255. Pheromone levels decay over time if they are not replenished
by the individuals in the area.

<a name="UsefulUtilityFunctions"></a>
### Useful utility functions

The utility function visitNeighborhood() in grid.cpp can be used to execute a
user-defined lambda or function over each location
within a circular neighborhood defined by a center point and floating point radius. The function
calls the user-defined function once for each location, passing it a Coord value. Only locations
within the bounds of the grid are visited. The center location is included among the visited
locations. For example, a radius of 1.0 includes only the center location plus four neighboring locations.
A radius of 1.5 includes the center plus all the eight-way neighbors. The radius can be arbitrarily large
but large radii require lots of CPU cycles.



<a name="InstallingTheCode"></a>
## Installing the code
--------------------

Copy the directory structure to a location of your choice.

<a name="BuildingTheExecutable"></a>
## Building the executable
--------------------

<a name="SystemRequirements"></a>
### System requirements

This code is known to run in the following environment:

* Linux 64 / Windows 64
* Lazarus-IDE 2.30
* FPC 3.2.0

<a name="Compiling"></a>
### Compiling

You have two options:

#### Using the Lazarus-IDE

Open the biosim.lpi file through the IDE and press F9

#### via console

call 

```sh
cd src
lazbuild -B biosim.lpi
```

<a name="Execution"></a>
## Execution
--------------------

Test everything is working by executing the Debug or Release executable in the bin directory with the default config file ("biosim4.ini"). e.g.:
```
./src/biosim4 biosim4.ini
```

You should have output something like:
`Gen 1, 2290 survivors`

If this works then edit the config file ("biosim4.ini") for the parameters you want for the simulation run and execute the Debug or Release executable. Optionally specify the name of the config file as the first command line argument, e.g.:

```
./src/biosim4 [biosim4.ini]
```

<a name="BuildLog"></a>
## Build log
--------------------

In case it helps for debugging the build process, here is a build log from Lazarus running under Linux Mint Mate 20.3:


```
-------------- Build: Release in biosim4 ---------------
lazbuild -B biosim.lpi

Hint: (11030) Start of reading config file /etc/fpc.cfg
Hint: (11031) End of reading config file /etc/fpc.cfg
Free Pascal Compiler version 3.2.2+dfsg-9ubuntu1 [2022/04/11] for x86_64
Copyright (c) 1993-2021 by Florian Klaempfl and others
(1002) Target OS: Linux for x86-64
(3104) Compiling biosim.lpr
(3104) Compiling usimulator.pas
(3104) Compiling uparams.pas
(3104) Compiling usimulator.pas
(3104) Compiling ugrid.pas
(3104) Compiling ubasictypes.pas
(3104) Compiling urandom.pas
(3104) Compiling usignals.pas
(3104) Compiling usimulator.pas
(3104) Compiling upeeps.pas
(3104) Compiling uindiv.pas
(3104) Compiling ugenome.pas
(3104) Compiling upeeps.pas
(3104) Compiling uindiv.pas
(3104) Compiling usensoractions.pas
(3104) Compiling usimulator.pas
(3104) Compiling upeeps.pas
(3104) Compiling usimulator.pas
(3104) Compiling uimagewriter.pas
(3104) Compiling /sda5/sda5/Tools/Projects/Sample/DatenSteuerung/ufifo.pas
(3104) Compiling /sda5/sda5/Tools/Projects/Sample/Graphik/ugwavi.pas
(3104) Compiling /sda5/sda5/Tools/Projects/Sample/Graphik/usimplechart.pas
(3104) Compiling /sda5/sda5/Tools/Projects/Sample/DatenSteuerung/uvectormath.pas
(3104) Compiling usimulator.pas
(3104) Compiling uspawnnewgeneration.pas
(3104) Compiling uanalysis.pas
/sda5/sda5/Tools/Projects/biosim/uanalysis.pas(89,149) Warning: (6018) unreachable code
(3104) Compiling uexecuteactions.pas
(3104) Compiling uendofsimstep.pas
(3104) Compiling uendofgeneration.pas
(3104) Compiling uunittests.pas
/sda5/sda5/Tools/Projects/biosim/uunittests.pas(80,35) Hint: (5024) Parameter "UserData" not used
(3104) Compiling uomp.pas
/sda5/sda5/Tools/Projects/biosim/usimulator.pas(62,33) Hint: (5024) Parameter "Sender" not used
/sda5/sda5/Tools/Projects/biosim/usimulator.pas(328,48) Hint: (5024) Parameter "Data" not used
/sda5/sda5/Tools/Projects/biosim/usimulator.pas(328,63) Hint: (5024) Parameter "Item" not used
/sda5/sda5/Tools/Projects/biosim/usimulator.pas(87,52) Hint: (5023) Unit "uUnittests" not used in uSimulator
/sda5/sda5/Tools/Projects/biosim/usimulator.pas(87,64) Hint: (5023) Unit "Math" not used in uSimulator
/sda5/sda5/Tools/Projects/biosim/uimagewriter.pas(43,60) Hint: (5024) Parameter "generation" not used
/sda5/sda5/Tools/Projects/biosim/uimagewriter.pas(50,26) Hint: (5024) Parameter "Value" not used
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1568,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1568,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1578,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1578,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1573,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1573,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1637,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1637,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1647,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1647,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1642,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1642,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1657,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1657,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1652,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1652,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1662,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1662,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1674,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1674,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1668,8) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.IndexOf(const AKey:LongInt):LongInt;" marked as inline is not inlined
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1679,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1679,1) Hint: (3124) Inlining disabled
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1684,1) Hint: (3123) "inherited" not yet supported inside inline procedure/function
/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl/fgl.ppu:fgl.pp(1684,1) Hint: (3124) Inlining disabled
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(336,21) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKeyData(const AKey:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(338,9) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutKeyData(const AKey:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(370,33) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(370,69) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(373,79) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKey(Index:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(444,20) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.IndexOf(const AKey:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(447,22) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.Add(const AKey:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(452,9) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutData(Index:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(454,19) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(461,7) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutData(Index:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(464,19) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKey(Index:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(469,20) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.IndexOf(const AKey:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(472,22) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.Add(const AKey:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(477,9) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutData(Index:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(479,19) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(481,7) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutData(Index:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(484,19) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKey(Index:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(559,17) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(561,5) Note: (6058) Call to subroutine "procedure TFPGMap<System.LongInt,uindiv.TNode>.PutData(Index:LongInt;const NewData:TNode);" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(580,94) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKeyData(const AKey:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(584,100) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKeyData(const AKey:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(600,100) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetKeyData(const AKey:LongInt):<record type>;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(616,24) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.IndexOf(const AKey:LongInt):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(622,26) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.Add(const AKey:LongInt;const AData:TNode):LongInt;" marked as inline is not inlined
/sda5/sda5/Tools/Projects/biosim/uindiv.pas(626,70) Note: (6058) Call to subroutine "function TFPGMap<System.LongInt,uindiv.TNode>.GetData(Index:LongInt):<record type>;" marked as inline is not inlined
(9022) Compiling resource /sda5/sda5/Tools/Projects/biosim/lib/x86_64-linux/biosim.or
(9015) Linking /sda5/sda5/Tools/Projects/biosim/biosim
(1008) 12881 lines compiled, 2.5 sec
(1021) 1 warning(s) issued
(1022) 34 hint(s) issued
(1023) 26 note(s) issued

```


