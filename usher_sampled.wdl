version 1.0

import "https://raw.githubusercontent.com/aofarrel/SRANWRP/v1.1.6/tasks/processing_tasks.wdl" as processing

# TODO: should eventually mark these tasks as volatile (https://cromwell.readthedocs.io/en/stable/optimizations/VolatileTasks/)

task usher_sampled_diff {
	input {
		Int batch_size_per_process = 5
		Boolean detailed_clades = false
		File diff
		File? i
		Int optimization_radius = 0
		Int max_parsimony_per_sample = 1000000
		Int max_uncertainty_per_sample = 1000000
		String outfile_usher
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
			--ref "~{ref}" \
			-o "~{outfile_usher}.pb"
		ls
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "yecheng/usher:latest"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File usher_tree = outfile_usher + ".pb"
		File? clades = "clades.txt" # only if detailed_clades = true
		File? ref_tree_summary = "ref_tree_summary.txt" # only if summarize_ref_tree = true
	}
}

task convert_to_taxonium {
	input {
		String outfile_taxonium
		File usher_tree
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
		# TODO: Tone down these attributes. This is probably overkill.
		bootDiskSizeGb: 25
		cpu: 16
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.6"
		memory: "16 GB"
		preemptible: 1
	}

	output {
		File taxonium_tree = outfile_taxonium + ".jsonl.gz"
	}
}

task convert_to_nextstrain {
	# based loosely on Marc Perry's version
	input {
		File usher_tree # aka tree_pb
		File? new_samples
		String outfile_nextstrain
		Int treesize = 0
		Int nearest_k = 500
		Int memory = 32
		Boolean new_samples_only = true
	}

	command <<<

		if [[ "~{new_samples_only}" = "false" ]]
		then
			matUtils extract -i	~{usher_tree} -S sample_paths.txt
			cut -f1 sample_paths.txt | tail -n +2 > sample.ids
			matUtils extract -i ~{usher_tree} -j ~{outfile_nextstrain}.json -s sample.ids -N ~{treesize}
		else
			matUtils extract -i ~{usher_tree} -j ~{outfile_nextstrain}.json -K ~{new_samples}:~{nearest_k}
		fi

		ls -lha
		
	>>>

	runtime {
		# TODO: Tone down these attributes. This is probably overkill.
		bootDiskSizeGb: 25
		cpu: 16
		disks: "local-disk " + 500 + " SSD"
		docker: "yecheng/usher:latest"
		memory: memory + " GB"
		preemptible: 1
	}

	output {
		Array[File] nextstrain_trees = glob("*.json")
	}
}

workflow usher_sampled_diff_to_taxonium {
	input {
		Array[File] diffs
		File? i
		Array[File] coverage_reports
		Float bad_data_threshold
		String outfile = "tree"
		File? ref
	}

	call processing.cat_files as cat_diff_files {
		input:
			files = diffs,
			out_filename = "cat_diff_files.txt",
			keep_only_unique_lines = false,
			removal_candidates = coverage_reports,
			removal_threshold = bad_data_threshold
	}

	call usher_sampled_diff {
		input:
			diff = cat_diff_files.outfile,
			i = i,
			outfile_usher = outfile,
			ref = ref
	}

	call convert_to_taxonium {
		input:
			outfile_taxonium = outfile,
			usher_tree = usher_sampled_diff.usher_tree
	}

	call convert_to_nextstrain {
		input:
			outfile_nextstrain = outfile,
			usher_tree = usher_sampled_diff.usher_tree,
			new_samples = cat_diff_files.first_lines
	}

	output {
		File usher_tree = usher_sampled_diff.usher_tree
		File taxonium_tree = convert_to_taxonium.taxonium_tree
		Array[File] nextstrain_trees = convert_to_nextstrain.nextstrain_trees
	}
}