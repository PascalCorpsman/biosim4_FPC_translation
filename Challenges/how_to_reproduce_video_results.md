## Instructions on how to reproduce the results shown in the youtube video
This fork started as a 1:1 port to FPC in order to verify its functionality
the examples shown in the original Youtube video where guessed / extracted and reproduced.

Link to the origin video: https://www.youtube.com/watch?v=N3tRFayqVtk&t=1s

##! Attention !
As all simulation runs did not run in deterministic mode, the results of your own runs may differ. I ran the simulations multiple times during testing and validating. In general i always got the more or less same results. But depending on the random behaviour it could be, that the results need more / less generations to get stable (e.g. the drop of the diversity of the "left_right_eights" Challenge, or the kill rates of the "Kill_neuron" Challenge).

## Timestamp 7:57 - 14:38 "Challenge_1_Right_Half.ini"
This is the first Challenge that "proof" the functionality of the simulator in general and how the simulator works. Main goal is to "learn to go to the right".

### Steps to reproduce:
* run with "Challenge_1_Right_Half.ini" and see results.

The Simulator not only learns to go to right, but also learns to "pack" the indivs to the right most.

## Timestamp 27:16 - 33:40 "Challenge_13_Left_Right_eights.ini"
This Challenge tries to show the importance of mutations and how to see its impact on the individuals.

### Steps to reproduce:
* run with "Challenge_13_Left_Right_eights_with_mutations.ini"
* run with "Challenge_13_Left_Right_eights_without_mutations.ini"

As you can see in both simulations the individuals do not take long to "learn" to go left and right to survive. The main reason for the simulation to wait until generation 5000 is to let the diversity go down to the lowest value "possible".

In generation 5000 the interesting thing happens (suddenly there are barriers created) and the indivs now need to adjust to the new situations. As you can see in the simulation with mutations allowed, the surviver rate starts again to raise (this is due to the fact of the mutations). On the other hand the indivs without mutations are not able to learn anything new and therefore the rate of survivers stays as low as directly after generation 5000 (this is due to the fact that the diversity is so low and the indivs are not able to get new "knowledge" through recombining their genes).

## Timestamp 35:54 - 40:52 "Challenge_6_Brain sizes"
This example shall show that the number of neurons and the brain size matters.

### Steps to reproduce:
* run with "Challenge_6_Weighted_Corners_Len_2.ini"
* run with "Challenge_6_Weighted_Corners_Len_8.ini"
* run with "Challenge_6_Weighted_Corners_Len_32.ini"
* run with "Challenge_6_Weighted_Corners_Len_1000.ini"

As you can see, when all 4 simulations finished the "bigger" the brain, the higher is the surviver rate.

2 genes, 1 inner ~ 35.1%
8 genes, 2 inner ~ 73.5%
32 genes, 5 inner ~ 82.2%
1000 genes, 127 inner ~ %
=> So keep care of your neurons ;)


## Timestamp 43:57 - 48:12 "Challenge_4_Unweighted_Center_Kill_neurons.ini"
This example makes use of the kill neuron, which is indeed a difficulty thing from the ethic viewpoint.

### Steps to reproduce:
* run with "Challenge_4_Weighted_Center_Kill_neurons.ini"
* run with "Challenge_40_Unweighted_Center_Kill_neurons.ini"

Both simulations 4 and 40 holds enough space for the population to reach 100% survivors. In the video the author suggest that he had used Challenge 40. As you can see in the results of Challenge 40, if there is no need to be violent the indivs loose this ability really soon and life in charm. You can clearly see that through mutations from time to time the "kill feature" comes back but dies out really soon again.
So i needed to switch to Challenge 4. This Challenge weights the indivs and increases the "preasure" by a tiny bit. Looking into the results the simulation shows that live in harmony is still possible (gen 0 .. 4000 and ~9000 .. 10000). But also live in violent is stable. Further can be seen, that if the violent is present the diversity always drops really fast (which is clear as all the "diverse" gene pool gets killed). By looking into the movies you can also see, that all the violent is reducing the intelligent behavoir of the population. The population looses the abillity to "find" the middle. The harmony phase from gen ~9000 to 10000 is to short to learn the best stragegy to survive again.

## Timestamp 52:15 - 55:38 "Challenge_10_Radioactive_walls.ini"
This simulation shall show how complex movements can be learned by the indivs. At first the left side of the world is deadly and at the second half of the life the right half.

### Steps to reproduce:
* run with "Challenge_10_Radioactive_walls.ini"

Reaching a 100% survivor rate is impossible, due to the fact that the indivs that are born at the left, more or less die instantly without any chance.
The best strategy you could evolve is, to run to the right the first half of the life and then go to the left the second half of the life. And thats exaktly what they learned.

