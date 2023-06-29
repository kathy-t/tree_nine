# README - for devs, maintainers, and other adventerous souls


## bogus fallbacks
WDL parsers -- as a consequence of WDL being a bit of an odd language -- do not properly understand "[iff](https://en.wikipedia.org/wiki/If_and_only_if) X happens when Y is true, and X happened, then Y is true." This means that I sometimes have to coerce optional types into not-optionals by using select_first(), where the second value is bogus.

The annotate task only runs if the metadata file, with optional type File?, is defined. So, you'd think that means you can input that metadata file into the annotate task like this:

```
if (defined(metadata_tsv_that_the_user_input)) {
		call annotate {
			input:
                metadata_tsv = metadata_tsv_that_the_user_input
```

Nope. Since the annotate task expects a File, not a File?, you have to use select_first(). You can't get away with select_first([metadata_tsv_that_the_user_input]) with most WDL parsers, so you need to define a fallback file. It doesn't really matter what the fallback file is, as long as the WDL parser thinks it's valid. Here, I choose the output UShER tree as the fallback. Obviously, passing in a phylogenetic tree in place of a TSV would break things -- but it won't, because barring a very strange bug in a WDL executor where a metadata TSV defines and then undefines itself, only the metadata TSV is ever going to be selected.

```
if (defined(metadata_tsv_that_the_user_input)) {
		call annotate {
			input:
                metadata_tsv = select_first([metadata_tsv_that_the_user_input, usher_sampled_diff.usher_tree]) # bogus fallback
```

This might beg the question as to why I don't just make the annotate task expect a File instead of a File?. The short answer is "because the one-liner select_first() hack is simpler." Optional types get messy very quickly, especially if you are dealing with scatters. Additionally, having an optional File? input into a task implies that the task doesn't actually need that file to run properly -- which isn't the case here; we need a metadata TSV if we're going to annotate.