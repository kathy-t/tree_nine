# Tree Nine
Put diff files on an existing phylogenetic tree using [UShER](https://www.nature.com/articles/s41588-021-00862-7)'s `usher sampled` task, followed by conversion to taxonium and Nextstrain formats.
 
## inputs
| type    	        | var                        	| default 	| description                                                           |
|--------------     |----------------------------	|---------	|-----------------------------------------------------------------------|
| Int?              | bad_data_threshold            |        	| remove files with coverage below this amount for bad data filtering   |
| Array[File]?      | coverage_reports              |        	| "reports" output from [myco](https://github.com/aofarrel/myco) for bad data filtering  |
| Int     	        | cpu                        	| 4       	| [Cloud only] number of cores<sup>†</sup> available                    |
| Boolean? 	        | detailed_clades            	| false   	| identical to usher equivalent                                         |
| File    	        | diff                       	|         	| identical to usher equivalent                                         |
| File?<sup>*</sup> | input_mutation_annotated_tree |         	| identical to usher i                                                  |
| Int?           	| max_parsimony_per_sample   	| 1000000 	| identical to usher equivalent                                         |
| Int?           	| max_uncertainty_per_sample 	| 1000000 	| identical to usher equivalent                                         |
| Int?           	| memory                     	| 8       	| [Cloud only] memory                                                   |
| Int?     	        | optimization_radius        	| 0       	| identical to usher equivalent                                         |
| String?        	| outfile                    	|        	| filename (no extension) to use on all output trees (overrides outfile_\*) |
| String?        	| outfile_nextstrain           	| "nextstrain"	| filename (no extension) of output nextstrain tree(s)              |
| String?        	| outfile_taxonium           	| "taxonium"	| filename (no extension) of output taxonium tree                   |
| String?        	| outfile_usher              	| "usher"	| filename (no extension) of output usher tree                          |
| Int?           	| preempt                    	| 1       	| [GCP only] preemptible attempts<sup>‡</sup>                           |
| File?<sup>*</sup> | ref                           |         	| identical to usher equivalent                                         |
| Boolean? 	        | summarize_ref_tree         	| false   	| if true, run `matUtils summary` on input tree before adding anything  |

<sup>*</sup>these shouldn't be considered optional -- they are marked as such to work around a WDL-specific limitation  
<sup>†</sup>does not directly set the `threads` value for usher, but by default usher will use all available cores  
<sup>‡</sup>ie, how many times should a preemptible be used for this task before trying a non-preemptible?  


## How to remove samples with bad coverage
If you created your diff files using [myco](https://github.com/aofarrel/myco), report files will be output alongside your diff files. Put these reports in as **coverage_reports** and set **bad_data_threshold** as the lowpass threshold for which you want to filter out files. For example, if you want to get rid of any sample for which has 5% or more low coverage sites, set **bad_data_threshold** to 0.05