version 1.0

task usher_sampled {
	input {
		File diff
		File i
		String outfile_usher
		File ref
	}

	Int disk_size = ceil(size(diff, "GB")) + ceil(size(ref, "GB")) +  ceil(size(i, "GB"))

	command <<<
		usher-sampled --optimization_radius=0 \
			--diff "~{diff}" \
			-i "~{i}" \
			--ref "~{ref}" \
			-o "~{outfile_usher}.pb"
		ls
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "quay.io/biocontainers/usher:0.6.1--h99b1ad8_1"
		memory: "8 GB"
		preemptible: 1
	}

	output {
		File usher_tree = outfile_usher + ".pb"
	}
}

task convert_to_taxonium {
	input {
		String outfile_taxonium
		File usher_tree
	}

	Int disk_size = ceil(size(usher_tree, "GB"))

	command <<<
		usher_to_taxonium -i "~{usher_tree}" -o "~{outfile_taxonium}.jsonl.gz"
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.4"
		memory: "8 GB"
		preemptible: 1
	}

	output {
		File taxonium_tree = outfile_taxonium + ".jsonl.gz"
	}
}

workflow usher_sampled_wf {
	input {
		File diff
		File i
		String outfile_usher = "newref"
		String outfile_taxonium = "newref"
		File ref
	}

	call usher_sampled {
		input:
			diff = diff,
			i = i,
			outfile_usher = outfile_usher,
			ref = ref
	}

	call convert_to_taxonium {
		input:
			outfile_taxonium = outfile_taxonium,
			usher_tree = usher_sampled.usher_tree
	}
}