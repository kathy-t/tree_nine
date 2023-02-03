version 1.0

import "https://raw.githubusercontent.com/aofarrel/SRANWRP/v1.1.4/tasks/processing_tasks.wdl" as processing

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
		docker: "ashedpotatoes/sranwrp:1.1.4"
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
		File tree_pb
		#File public_meta
		#File samples_meta
		String prefix
		Int treesize
		String public_json_bucket
		Int num_threads = 80
		Int mem_size = 640
		Int diskSizeGB = 375
		File script
	}
    String nextstr = "https://nextstrain.org/fetch/storage.googleapis.com"

    command <<<
    	# matUtils extract -i mmm/new_usher/newtree.pb -S sample_paths.txt
    	# cut -f1 sample_paths.txt | tail -n +2 > sample.ids
    	# matUtils extract -i mmm/new_usher/newtree.pb -j subtree -s sample.ids -N 1
		matUtils extract -i	~{tree_pb} -S sample_paths.txt
		cut -f1 sample_paths.txt | tail -n +2 > sample.ids
		matUtils extract -i ~{tree_pb} -j subtree -s sample.ids
    >>>

workflow usher_sampled_diff_to_taxonium {
	input {
		Array[File] diffs
		File? i
		String outfile_usher = "newtree"
		String outfile_taxonium = "newtree"
		File? ref
	}

	call processing.cat_files as cat_diff_files {
		input:
			files = diffs,
			out_filename = "cat_diff_files.txt",
			keep_only_unique_lines = false
	}

	call usher_sampled_diff {
		input:
			diff = cat_diff_files.outfile,
			i = i,
			outfile_usher = outfile_usher,
			ref = ref
	}

	call convert_to_taxonium {
		input:
			outfile_taxonium = outfile_taxonium,
			usher_tree = usher_sampled_diff.usher_tree
	}

	output {
		File usher_tree = usher_sampled_diff.usher_tree
		File taxonium_tree = convert_to_taxonium.taxonium_tree
	}
}