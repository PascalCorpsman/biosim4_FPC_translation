## Instructions on how to Reproduce the results shown in the youtube video
This fork started as a 1:1 port to FPC in order to verify its functionality
the examples shown in the original Youtube video where extracted and reproduced.

Link to the origin video: https://www.youtube.com/watch?v=N3tRFayqVtk&t=1s

## Timestamp 7:57 - 14:38 "Challange_1_Right_Half.ini"
This is the first challange that "proof" the functionality of the simulator in general and how the simulator works. Main goal is to "learn to go to the right".
### Steps to reproduce:
* run with "Challange_1_Right_Half.ini" and see results.

## Timestamp 27:16 - 33:40 "Challange_13_Left_Right_eights.ini"
This challange tries to show the importance of mutations and how to see its impact on the individuals.

### Steps to reproduce:
* run with "Challange_13_Left_Right_eights_with_mutations.ini"
* run with "Challange_13_Left_Right_eights_without_mutations.ini"

As you can see in both simulations the individuals do not take long to "learn" to go left and right to survive. The main reason for the simulation to wait until generation 5000 is to let the diversity go down to the lowest value "possible".

In generation 5000 the interesting thing happens (suddenly there are barriers created) and the individuums now need to adjust to the new situations. As you can see in the simulation with mutations allowed, the surviver rate starts again to raise (this is due to the fact of the mutations). On the other hand the individuums without mutations are not able to learn anything new and therefore the rate of survivers stays as low as direktly after generation 5000 (this is due to the fact that the diversity is so low and the individuums are not able to get new "knowledge" through recombining their genes).


## Timestamp 35:54 - 40:52 Brain sizes
* run with "Challange_6_Weighted_Corners_Len_2.ini"
* run with "Challange_6_Weighted_Corners_Len_8.ini"
* run with "Challange_6_Weighted_Corners_Len_32.ini"
* run with "Challange_6_Weighted_Corners_Len_1000.ini"

As you can see when all 4 simulations finished the "bigger" the brain, the higher is the surviver rate

2 genes, 1 inner ~ 45.2%
8 genes, 2 inner ~ 77.5%
32 genes, 5 inner ~ 78.4%
1000 genes, 127 inner ~ %


## Timestamp 43:57 - 48:12 "Challange_4_Unweighted_Center_Kill_neurons.ini"
* run with "Challange_4_Weighted_Center_Kill_neurons.ini"
* maybe run with "Challange_40_Unweighted_Center_Kill_neurons.ini"

Results here are not that simple, as you can see in the different runs, if there is no need to fight the individuals tend to loose the ability to kill. To get the results similar to the ones in the video i needed to change the challange from 40 to 4, this increases the preasure on the individuals and then they startet to make use of the kill feature. Both versions i uploaded are showing that a stable run without killing is possible. But if the murder genes spread through out all the population the violent does not stop anymore.

## Timestamp 52:15 - 55:38 "Challange_10_Radioactive_walls.ini"

### Steps to reproduce:
