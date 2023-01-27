# usher-sampled-wdl
 Unofficial partial WDLization of [UShER](https://www.nature.com/articles/s41588-021-00862-7)'s `usher sampled` task, followed by conversion to taxonium.
 
## inputs
| type    	| var                        	| default 	| description                                                           |
|---------	|----------------------------	|---------	|-----------------------------------------------------------------------|
| Int     	| cpu                        	| 4       	| [Cloud only] number of cores<sup>†</sup> available                    |
| Boolean 	| detailed_clades            	| false   	| identical to usher equivalent                                         |
| File    	| diff                       	|         	| identical to usher equivalent                                         |
| File?<sup>*</sup>   	| i                 |         	| identical to usher equivalent                                         |
| Int     	| optimization_radius        	| 0       	| identical to usher equivalent                                         |
| Int     	| max_parsimony_per_sample   	| 1000000 	| identical to usher equivalent                                         |
| Int     	| max_uncertainty_per_sample 	| 1000000 	| identical to usher equivalent                                         |
| String  	| outfile_taxonium           	| "newtree"	| filename (no extension) of output taxonium tree                       |
| String  	| outfile_usher              	| "newtree"	| identical to usher equivalent                                         |
| Int     	| preempt                    	| 1       	| [GCP only] preemptible attempts<sup>‡</sup>                           |
| File?<sup>*</sup>   	| ref               |         	| identical to usher equivalent                                         |
| Boolean 	| summarize_ref_tree         	| false   	| if true, run `matUtils summary` on input tree before adding anything  |
| Int     	| memory                     	| 8       	| [Cloud only] memory                                                   |

<sup>*</sup>these shouldn't be considered optional -- they are marked as such to work around a WDL-specific limitation  
<sup>†</sup>does not directly set the `threads` value for usher, but by default usher will use all available cores  
<sup>‡</sup>ie, how many times should a preemptible be used for this task before trying a non-preemptible?  
