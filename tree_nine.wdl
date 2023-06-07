version 1.0

import "https://raw.githubusercontent.com/aofarrel/SRANWRP/v1.1.12/tasks/processing_tasks.wdl" as processing

# TODO: should eventually mark these tasks as volatile (https://cromwell.readthedocs.io/en/stable/optimizations/VolatileTasks/)

workflow usher_sampled_diff_to_taxonium {
	input {
		# these inputs are required (some are marked optional to get around WDL limitations)
		Array[File] diffs
		File? input_mutation_annotated_tree  # equivalent to UShER's i argument

		# actually optional inputs
		Float? max_low_coverage_sites
		Array[File]? coverage_reports
		Boolean make_nextstrain_subtrees = true
		String? outfile
		File? ref                            # equivalent to USHER's ref argument
	}

	parameter_meta {
		diffs: "Array of diff files"
		input_
	}

	call processing.cat_files as cat_diff_files {
		input:
			files = diffs,
			out_filename = "cat_diff_files.txt",
			keep_only_unique_lines = false,
			removal_candidates = coverage_reports,
			removal_threshold = max_low_coverage_sites,
			output_first_lines = true
	}

	call usher_sampled_diff {
		input:
			diff = cat_diff_files.outfile,
			i = input_mutation_annotated_tree,
			outfile_usher = outfile,
			ref = ref
	}

	call convert_to_taxonium {
		input:
			outfile_taxonium = outfile,
			usher_tree = usher_sampled_diff.usher_tree
	}

	if (make_nextstrain_subtrees) {
		call convert_to_nextstrain_subtrees {
			input:
				outfile_nextstrain = outfile,
				usher_tree = usher_sampled_diff.usher_tree,
				new_samples = cat_diff_files.first_lines
		}
	}
	if (!make_nextstrain_subtrees) {
		call convert_to_nextstrain_single {
			input:
				outfile_nextstrain = outfile,
				usher_tree = usher_sampled_diff.usher_tree
		}
	}

	output {
		File usher_tree = usher_sampled_diff.usher_tree
		File taxonium_tree = convert_to_taxonium.taxonium_tree
		File? nextstrain_tree = convert_to_nextstrain_single.nextstrain_singular_tree
		Array[File]? nextstrain_subtrees = convert_to_nextstrain_subtrees.nextstrain_subtrees
	}
}

task usher_sampled_diff {
	input {
		Int batch_size_per_process = 5
		Boolean detailed_clades = false
		File diff
		File? i
		Int optimization_radius = 0
		Int max_parsimony_per_sample = 1000000
		Int max_uncertainty_per_sample = 1000000
		String outfile_usher = "usher"
		File? ref

		# WDL specific -- note that cpu does not directly set usher's
		# threads argument, but it does affect the number of cores
		# available for use (by default usher uses all available)
		Int addldisk = 10
		Int cpu = 8
		Int memory = 16
		Int preempt = 1
		Boolean summarize_ref_tree = false
	}

	Int disk_size = ceil(size(diff, "GB")) + ceil(size(ref, "GB")) +  ceil(size(i, "GB")) + addldisk
	String detailed_clades_arg = if !(detailed_clades) then "" else "-D "
	String reference = select_first([ref, "/HOME/usher/ref/Ref.H37Rv/ref.fa"])

	command <<<
		if [ "~{summarize_ref_tree}" == "true" ]
		then
			matUtils summary -i ~{i} > ref_tree_summary.txt
		fi
		usher-sampled ~{detailed_clades_arg} --optimization_radius=~{optimization_radius} \
			-e ~{max_uncertainty_per_sample} \
			-E ~{max_parsimony_per_sample} \
			--batch_size_per_process ~{batch_size_per_process} \
			--diff "~{diff}" \
			-i "~{i}" \
			--ref "~{reference}" \
			-o "~{outfile_usher}.pb"
		ls
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/usher-plus:0.0.1"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File usher_tree = outfile_usher + ".pb"
		File? clades = "clades.txt" # only if detailed_clades = true
		File? ref_tree_summary = "ref_tree_summary.txt" # only if summarize_ref_tree = true
	}

	meta {
		volatile: true
	}
}

task annotate {
	input {
		File input_tree
		File metadata_tsv # only can annotate one column at a time

		Boolean summarize = false
		String outfile_usher = "annotated"		
	}
	command <<< 
	matUtils annotate -i "~{input_tree}" -c "~{metadata_tsv}" -o "~{outfile_usher}.pb"
	if [[ "~{summarize}" = true ]]
	then
		matUtils summary -i "~{outfile_usher}.pb" -C samplecladeinfo.tsv
	fi
	>>>

	output {
		File usher_tree = outfile_usher + ".pb"
		File? clades = "samplecladeinfo.tsv" # only if summarize = true
	}

}

task convert_to_taxonium {
	input {
		File usher_tree
		String outfile_taxonium = "taxonium"
	}

	Int disk_size = ceil(size(usher_tree, "GB")) + 100

	command <<<
		echo "booted into Docker successfully"
		echo "input file: ~{usher_tree}"
		ls -lha ~{usher_tree}
		echo "running usher_to_taxonium..."
		usher_to_taxonium -i "~{usher_tree}" -o "~{outfile_taxonium}.jsonl.gz"
	>>>

	runtime {
		bootDiskSizeGb: 15
		cpu: 12
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "16 GB"
		preemptible: 1
	}

	output {
		File taxonium_tree = outfile_taxonium + ".jsonl.gz"
	}
}

task convert_to_nextstrain_subtrees {
	# based loosely on Marc Perry's version
	input {
		File usher_tree # aka tree_pb
		File? new_samples
		Int treesize = 0
		Int nearest_k = 250
		Int memory = 32
		Boolean new_samples_only = true
		String outfile_nextstrain = "nextstrain"
	}

	command <<<

		if [[ "~{new_samples_only}" = "false" ]]
		then
			matUtils extract -i	~{usher_tree} -S sample_paths.txt
			cut -f1 sample_paths.txt | tail -n +2 > sample.ids
			matUtils extract -i ~{usher_tree} -j ~{outfile_nextstrain}.json -s sample.ids -N ~{treesize}
		else
			if [[ "~{new_samples}" == "" ]]
			then
				echo "Error -- new_samples_only is true, but no new_samples files was provided."
				exit 1
			else
				matUtils extract -i ~{usher_tree} -j ~{outfile_nextstrain}.json -s ~{new_samples} -N ~{nearest_k}
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
		File usher_tree # aka tree_pb
		Int memory = 32
		String outfile_nextstrain = "nextstrain"
	}

	command <<<
		matUtils extract -i ~{usher_tree} -j ~{outfile_nextstrain}.json
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
		File nextstrain_singular_tree = outfile_nextstrain+".json"
	}
}