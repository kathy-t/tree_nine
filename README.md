# Tree Nine
Put diff files on an existing phylogenetic tree using [UShER](https://www.nature.com/articles/s41588-021-00862-7)'s `usher sampled` task with a bit of help from [SRANWRP](https://www.github.com/aofarrel/SRANWRP), followed by conversion to taxonium and Nextstrain/Auspice formats. Auspice sometimes struggles to load a large bacterial phylo tree, so there is the option to output subtrees instead of one very large tree.

Verified on Terra-Cromwell and miniwdl. Make sure to add `--copy-input-files` for miniwdl. Default inputs assume you're working with _Mycobacterium tuberculosis_, be sure to change them if you aren't working with that bacterium.
 
## inputs
| type    	        | var                        	| default 	| description                                                           |
|--------------     |----------------------------	|---------	|-----------------------------------------------------------------------|
| Array[File]?      | coverage_reports              |        	| "reports" output from [myco](https://github.com/aofarrel/myco) for bad data filtering  |
| Int     	        | cpu                        	| (varies) 	| [Cloud only] number of cores<sup>†</sup> available                    |
| Boolean? 	        | detailed_clades            	| false   	| identical to usher equivalent                                         |
| Array[File]       | diff                       	|         	| identical to usher equivalent                                         |
| File?             | input_mutation_annotated_tree | <sup>‡</sup> | identical to usher i                                              |
| Boolean           | make_nextstrain_subtrees      | true   	| if true, make Nextstrain subtrees; if false, make one big Nextstrain tree (which might lag in Auspice)  |
| Float?            | max_low_coverage_sites        |        	| remove files with coverage below this amount for bad data filtering   |
| Int?           	| max_parsimony_per_sample   	| 1000000 	| identical to usher equivalent                                         |
| Int?           	| max_uncertainty_per_sample 	| 1000000 	| identical to usher equivalent                                         |
| Int?           	| memory                     	| (varies)	| [Cloud only] memory                                                   |
| File?           	| metadata_tsv                	|        	| TSV with metadata to annotate (currently unused)                      |
| Int?     	        | optimization_radius        	| 0       	| identical to usher equivalent                                         |
| String?        	| out_prefix           	        | "tree"	| prefix for all outputs                                                |
| Int?           	| preempt                    	| 1       	| [GCP only] preemptible attempts                                       |
| File?             | ref                           | H37Rv 	| identical to usher equivalent                                         |
| String?        	| reroot_to_this_node           |        	| reroot output tree to this node - **do NOT define this if you don't want to reroot**              |
| String?        	| subtree_only_new_samples      | true   	| if true and if `make_nextstrain_subtrees` true, subtrees will only be focused on samples added by your diffs              |


<sup>†</sup>does not directly set the `threads` value for usher, but by default usher will use all available cores  
<sup>‡</sup>a sample .pb created from SRA data is present in this repo and the Docker image used by this workflow, and it will be the fallback input mat if not provided by the user -- **but this default tree should only be used for debugging purposes** 


## how to remove samples with bad coverage
If you created your diff files using [myco](https://github.com/aofarrel/myco), report files will be output alongside your diff files. Put these reports in as **coverage_reports** and set **bad_data_threshold** as the lowpass threshold for which you want to filter out files. For example, if you want to get rid of any sample for which has 5% or more low coverage sites, set **bad_data_threshold** to 0.05