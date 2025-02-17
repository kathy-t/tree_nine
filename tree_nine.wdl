version 1.0

import "https://raw.githubusercontent.com/aofarrel/SRANWRP/v1.1.14/tasks/processing_tasks.wdl" as processing

workflow Tree_Nine {
	input {
		# these inputs are required (some are marked optional to get around WDL limitations)
		Array[File] diffs
		File? input_tree  # equivalent to UShER's i argument

		# optional inputs - filtering by coverage
		Array[File]? coverage_reports
		Float? max_low_coverage_sites
		
		# optional inputs - building trees
		Boolean detailed_clades = false
		Boolean make_nextstrain_subtrees = true
		Boolean subtree_only_new_samples = true
		Boolean summarize_input_mat = true
		String? reroot_to_this_node          # equivalent to matUtils extract's y argument
		File? ref_genome                     # equivalent to USHER's ref argument
		File? metadata_tsv

		# output file names, extension not included
		String out_prefix         = "tree"
		String out_prefix_summary = out_prefix + "_"
		String in_prefix_summary  = basename(select_first([input_tree, "tb_alldiffs_mask2ref.L.fixed"]))
		String out_diffs               = "_combined"
		String out_tree_annotated_pb   = "_annotated"
		String out_tree_nextstrain     = "_auspice"
		String out_tree_nwk            = "_nwk"
		String out_tree_taxonium       = "_taxonium"
		String out_tree_raw_pb         = "_raw"
		
	}

	parameter_meta {
		coverage_reports: "Single line text files generated by Lily's vcf to diff script, used to filter samples with low overall coverage"
		diffs: "Array of diff files"
		input_tree: "Input tree, equivalent to UShER's i argument"
		metadata_tsv: "TSV with one column of metadata"

		detailed_clades: "If true, run usher sampled diff with -D"
		max_low_coverage_sites: "Maximum percentage of low coverage sites a sample can have before throwing it out"
		make_nextstrain_subtrees: "If true, make nextstrain subtrees instead of one big nextstrain tree"
		ref_genome: "Reference genome, equivalent to UShER's ref argument, default is H37Rv (M tuberculosis)"
		reroot_to_this_node: "Reroot the output tree relative to this node, leave blank to not reroot"
		out_prefix: "Prefix for all output files"
		subtree_only_new_samples: "If true and if make_nextstrain_subtrees true, nextstrain subtrees will only be focused on newly samples (ie samples added by your diffs)"
		summarize_input_mat: "If true and if an input tree is passed in, summarize that input tree"
	}

	call processing.cat_files as cat_diff_files {
		input:
			files = diffs,
			out_filename = out_prefix + out_diffs + ".diff",
			keep_only_unique_lines = false,
			removal_candidates = coverage_reports,
			removal_threshold = max_low_coverage_sites,
			output_first_lines = true,
			first_lines_out_filename = "samples_added"
	}

	File new_samples_added = select_first([cat_diff_files.first_lines, usher_sampled_diff.usher_tree]) # bogus fallback

	if((summarize_input_mat)) {
		if (defined(input_tree)) {
			String basename_input_mat = basename(select_first([input_tree, ""]))

			# iff there is a metadata tsv, annotate input tree with it before summarizing
			if (defined(metadata_tsv)) {
				String annotated = "annotated_"
				call annotate as annotate_input_tree {
					input:
						input_mat = select_first([input_tree, usher_sampled_diff.usher_tree]), # bogus fallback
						metadata_tsv = select_first([metadata_tsv, usher_sampled_diff.usher_tree]), # bogus fallback
						outfile_annotated = "input_annotated_" + basename_input_mat + ".pb"
				}
			}

			File possibly_annotated_input_tree = select_first([annotate_input_tree.annotated_tree, input_tree])
			String annotated_or_blank = select_first([annotated, ""])

			call summarize as summarize_input_tree {
				input:
					input_mat = possibly_annotated_input_tree,
					prefix_outs = "input_" + annotated_or_blank + basename_input_mat
			}
		}
	}

	call usher_sampled_diff {
		input:
			detailed_clades = detailed_clades,
			diff = cat_diff_files.outfile,
			input_mat = input_tree,
			output_mat = out_prefix + out_tree_raw_pb + ".pb",
			ref_genome = ref_genome
	}

	if (defined(metadata_tsv)) {
		call annotate as annotate_output_tree {
			input:
				input_mat = usher_sampled_diff.usher_tree,
				metadata_tsv = select_first([metadata_tsv, usher_sampled_diff.usher_tree]), # bogus fallback
				outfile_annotated = out_prefix + out_tree_annotated_pb + ".pb"
		}
	}

	File possibly_annotated_output_tree = select_first([annotate_output_tree.annotated_tree, usher_sampled_diff.usher_tree])

	if(defined(reroot_to_this_node)) {

		call summarize as summarize_output_tree_before_reroot {
			input:
				input_mat = possibly_annotated_output_tree,
				prefix_outs = "before_reroot"
		}

		call reroot {
			input:
				input_mat = possibly_annotated_output_tree,
				reroot_to_this_node = select_first([reroot_to_this_node, ""])
		}
	}

	File final_output_tree = select_first([reroot.rerooted_tree, possibly_annotated_output_tree])

	# defined(metadata_tsv)   defined(reroot_to_this_node)          final_output_tree
	# ----------------------------------------------------------------------------------------------------------------
	#       true                       true                    annotated and rerooted
	#       true                      false                    annotated
	#       false                      true                    rerooted
	#       false                     false                    neither, just the output usher_sampled_diff.usher_tree

	call convert_to_newick {
		input:
			input_mat = final_output_tree,
			outfile_nwk = out_prefix + out_tree_nwk + ".nwk"
	}

	call convert_to_taxonium {
		input:
			input_mat = final_output_tree,
			outfile_taxonium = out_prefix + out_tree_taxonium + ".jsonl.gz"
	}

	if (make_nextstrain_subtrees) {
		call convert_to_nextstrain_subtrees {
			input:
				input_mat = final_output_tree,
				outfile_nextstrain = out_prefix + out_tree_nextstrain + ".json",
				new_samples = cat_diff_files.first_lines,
				new_samples_only = subtree_only_new_samples
		}
	}
	if (!make_nextstrain_subtrees) {
		call convert_to_nextstrain_single {
			input:
				input_mat = final_output_tree,
				outfile_nextstrain = out_prefix + out_tree_nextstrain + ".json"
		}
	}

	call summarize as summarize_output_tree {
		input:
			input_mat = final_output_tree,
			prefix_outs = out_prefix_summary
	}

	output {
		# trees - protobuff
		#
		# note that tree_usher_rerooted is annotated if defined(metadata_tsv), but tree_usher_annotated is NOT rerooted
		# even if defined(reroot_to_this_node) -- this was done on purpose so people can get two annotated trees if they
		# want to easily compare the tree before and after rerooting
		File tree_usher_raw = usher_sampled_diff.usher_tree                                   # always
		File? tree_usher_rerooted = reroot.rerooted_tree                                      # iff defined(reroot_to_this_node)
		File? tree_usher_annotated = annotate_output_tree.annotated_tree                      # iff defined(metadata_tsv)

		# trees - other formats
		#
		# iff defined(reroot_to_this_node), these are based on usher_tree_rerooted
		# else, these are based on usher_tree_raw (and usher_tree_rerooted doesn't exist
		File tree_nwk = convert_to_newick.newick_tree                                         # always
		File tree_taxonium = convert_to_taxonium.taxonium_tree                                # always
		File? tree_nextstrain = convert_to_nextstrain_single.nextstrain_singular_tree         # mutually exclusive with nextstrain_subtrees
		Array[File]? subtrees_nextstrain = convert_to_nextstrain_subtrees.nextstrain_subtrees # mutually exclusive with nextstrain_tree

		# summaries
		File? summary_input = summarize_input_tree.summary                                    # iff summarize_input_mat
		File summary_output = summarize_output_tree.summary                                   # always
		File? summary_output_before_reroot = summarize_output_tree_before_reroot.summary      # iff defined(reroot_to_this_node)

		# sample information
		File? samples_input_tree = summarize_input_tree.samples                                # iff summarize_input_mat
		File samples_output_tree = summarize_output_tree.samples                               # always
		File? samples_output_tree_before_reroot = summarize_output_tree_before_reroot.samples  # iff defined(reroot_to_this_node)
		Array[String] samples_added = read_lines(new_samples_added)                            # always
		Array[String] samples_dropped = cat_diff_files.removed_files                           # always
	}
}

task usher_sampled_diff {
	input {
		Int batch_size_per_process = 5
		Boolean detailed_clades
		File diff
		File? input_mat
		Int optimization_radius = 0
		Int max_parsimony_per_sample = 1000000
		Int max_uncertainty_per_sample = 1000000
		String output_mat
		File? ref_genome

		# WDL specific -- note that cpu does not directly set usher's
		# threads argument, but it does affect the number of cores
		# available for use (by default usher uses all available)
		Int addldisk = 10
		Int cpu = 8
		Int memory = 16
		Int preempt = 1
	}

	Int disk_size = ceil(size(diff, "GB")) + ceil(size(ref_genome, "GB")) +  ceil(size(input_mat, "GB")) + addldisk
	String D = if !(detailed_clades) then "" else "-D "
	#String ref = select_first([ref_genome, "/HOME/usher/ref/Ref.H37Rv/ref.fa"])
	#String i = select_first([input_mat, "/HOME/usher/example_tree/tb_alldiffs_mask2ref.L.fixed.pb"])

	command <<<
		if [[ "~{input_mat}" = "" ]]
		then
			i="/HOME/usher/example_tree/tb_alldiffs_mask2ref.L.fixed.pb"
		else
			i="~{input_mat}"
		fi

		if [[ "~{ref_genome}" = "" ]]
		then
			ref="/HOME/usher/ref/Ref.H37Rv/ref.fa"
		else
			ref="~{ref_genome}"
		fi
		
		echo "~{input_mat}"
		echo $i
		echo "~{ref_genome}"
		echo $ref
		echo "------------------"
		ls -lha
		echo "------------------"

		usher-sampled ~{D} --optimization_radius=~{optimization_radius} \
			-e ~{max_uncertainty_per_sample} \
			-E ~{max_parsimony_per_sample} \
			--batch_size_per_process ~{batch_size_per_process} \
			--diff "~{diff}" \
			-i "$i" \
			--ref "$ref" \
			-o "~{output_mat}"
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/usher-plus:0.0.2"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File usher_tree = output_mat
		File? clades = "clades.txt" # only if detailed_clades = true
	}

	meta {
		volatile: true
	}
}

task reroot {
	input {
		File input_mat
		String reroot_to_this_node

		Int addldisk = 10
		Int cpu = 8
		Int memory = 16
		Int preempt = 1
	}
	Int disk_size = ceil(size(input_mat, "GB")) + addldisk
	String output_mat = basename(input_mat, ".pb") + ".reroot_to_~{reroot_to_this_node}" + ".pb"

	command <<<
	if [[ "~{reroot_to_this_node}" = "" ]]
	then
		echo "You need to specify the node to reroot upon"
		exit 1
	fi
	matUtils extract -i "~{input_mat}" -y "~{reroot_to_this_node}" -o "~{output_mat}"
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/usher-plus:0.0.2"
		memory: memory + " GB"
		preemptible: preempt
	}
	
	output {
		File rerooted_tree = output_mat
	}
}

task summarize {
	# Generates most of the possible outputs of matUtils summarize:
	#
	# --samples (-s): Write a two-column tsv listing all samples in the tree and their parsimony score (terminal branch length). Auspice-compatible.
	# --clades (-c): Write a tsv listing all clades and the count of associated samples in the tree.
	# --mutations (-m): Write a tsv listing all mutations in the tree and their occurrence count.
	# --aberrant (-a): Write a tsv listing potentially problematic nodes, including duplicates and internal nodes with no mutations and/or branch length 0.
	# --haplotype (-H): Write a tsv listing haplotypes represented by comma-delimited lists of mutations and their count across the tree.
	# --sample-clades (-C): Write a tsv listing all samples and their clades.
	# --calculate-roho (-R): Write a tsv listing, for each mutation occurrence that is valid, the number of offspring and other numbers for RoHo calculation.
	#
	# Two outputs are not generated:
	# * expanded_roho: this slows things down too much
	# * translate: this would require taking in a gtf and ref genome

	input {
		File? input_mat
		String? prefix_outs

		Int addldisk = 10
		Int cpu = 8
		Int memory = 16
		Int preempt = 1
	}
	Int disk_size = if defined(input_mat) then ceil(size(input_mat, "GB")) + addldisk else addldisk
	String prefix = select_first([prefix_outs, ""])

	command <<< 
	if [[ "~{input_mat}" = "" ]]
	then
		i="/HOME/usher/example_tree/tb_alldiffs_mask2ref.L.fixed.pb"
	else
		i="~{input_mat}"
	fi
	
	matUtils summary -i "$i" > "~{prefix}summary.txt"
	matUtils summary -i "$i" -A # samples, clades, mutations, aberrant
	matUtils summary -i "$i" -H haplotypes.tsv
	matUtils summary -i "$i" -C sample_clades.tsv
	matUtils summary -i "$i" -R roho.tsv
	for file in *.tsv
	do
		mv -- "$file" "~{prefix}${file}"
	done
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/usher-plus:0.0.2"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File summary = prefix + "summary.txt"
		File samples = prefix + "samples.tsv"
		File clades = prefix + "clades.tsv"
		File mutations = prefix + "mutations.tsv"
		File aberrant = prefix + "aberrant.tsv"
		File haplotype = prefix + "haplotypes.tsv"
		File sample_clades = prefix + "sample_clades.tsv"
		File calculate_roho = prefix + "roho.tsv"
	}
}

task annotate {
	input {
		File? input_mat
		File metadata_tsv # only can annotate one column at a time
		String outfile_annotated

		Int addldisk = 10
		Int cpu = 8
		Int memory = 16
		Int preempt = 1
	}
	Int disk_size = ceil(size(input_mat, "GB")) + ceil(size(metadata_tsv, "GB")) + addldisk

	command <<< 
	matUtils annotate -i "~{input_mat}" -c "~{metadata_tsv}" -o "~{outfile_annotated}"
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/usher-plus:0.0.2"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File annotated_tree = outfile_annotated
	}

}

task convert_to_taxonium {
	input {
		File input_mat
		String outfile_taxonium

		Int addldisk = 100
		Int cpu = 12
		Int memory = 16
		Int preempt = 1
	}

	Int disk_size = ceil(size(input_mat, "GB")) + addldisk

	command <<<
		echo "booted into Docker successfully"
		echo "input file: ~{input_mat}"
		ls -lha ~{input_mat}
		echo "running usher_to_taxonium..."
		usher_to_taxonium -i "~{input_mat}" -o "~{outfile_taxonium}"
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File taxonium_tree = outfile_taxonium
	}
}

task convert_to_nextstrain_subtrees {
	# based loosely on Marc Perry's version
	input {
		File input_mat # aka tree_pb
		File? new_samples
		Int treesize = 0
		Int nearest_k = 250
		Int memory = 32
		Boolean new_samples_only
		String outfile_nextstrain = "nextstrain"
	}

	command <<<

		if [[ "~{new_samples_only}" = "false" ]]
		then
			matUtils extract -i	~{input_mat} -S sample_paths.txt
			cut -f1 sample_paths.txt | tail -n +2 > sample.ids
			matUtils extract -i ~{input_mat} -j ~{outfile_nextstrain}.json -s sample.ids -N ~{treesize}
		else
			if [[ "~{new_samples}" == "" ]]
			then
				echo "Error -- new_samples_only is true, but no new_samples files was provided."
				exit 1
			else
				matUtils extract -i ~{input_mat} -j ~{outfile_nextstrain}.json -s ~{new_samples} -N ~{nearest_k}
			fi
		fi
		ls -lha
		
	>>>

	runtime {
		bootDiskSizeGb: 15
		cpu: 12
		disks: "local-disk " + 150 + " SSD"
		docker: "yecheng/usher:latest"
		memory: memory + " GB"
		preemptible: 1
	}

	output {
		Array[File] nextstrain_subtrees = glob("*.json")
	}
}

task convert_to_nextstrain_single {
	input {
		File input_mat # aka tree_pb
		Int memory = 32
		String outfile_nextstrain
	}

	command <<<
		matUtils extract -i ~{input_mat} -j ~{outfile_nextstrain}
	>>>

	runtime {
		bootDiskSizeGb: 15
		cpu: 12
		disks: "local-disk " + 150 + " SSD"
		docker: "yecheng/usher:latest"
		memory: memory + " GB"
		preemptible: 1
	}

	output {
		File nextstrain_singular_tree = outfile_nextstrain
	}
}

task convert_to_newick {
	input {
		File input_mat
		String outfile_nwk
	}

	command <<<
		matUtils extract -i ~{input_mat} -t ~{outfile_nwk}
	>>>

	runtime {
		bootDiskSizeGb: 15
		cpu: 8
		disks: "local-disk " + 100 + " SSD"
		docker: "yecheng/usher:latest"
		memory: 8 + " GB"
		preemptible: 1
	}

	output {
		File newick_tree = outfile_nwk
	}
}