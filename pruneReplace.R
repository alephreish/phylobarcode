#!/usr/bin/Rscript

if (!("ape" %in% rownames(installed.packages()))) {
	write("ape package not installed", stderr())
	quit(status=1)
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
	write("Use as follows:", stderr())
	write("pruneReplace.R tree.file otus.file", stderr())
	quit(status=1)
}

library(ape)

tree.file <- args[1]
otus.file <- args[2]

mytree <- read.tree(tree.file)

col.num <- max(count.fields(otus.file, sep = "\t"))
otus <- read.table(otus.file, sep = "\t", fill = T, header = F, col.names = paste0("V", 1:col.num))

seq.names <- split(otus[,-1], 1:nrow(otus))
seq.names <- lapply(seq.names, function(x) x[x != ""])
names(seq.names) <- otus[,1]
wrap.names <- function(x) {
	y <- paste(x, collapse = ",")
	if (length(x) > 1) y <- paste0("(", y, ")")
	return(y)
}
seq.replace <- unlist(lapply(seq.names, wrap.names))

pruned <- drop.tip(mytree, setdiff(mytree$tip.label, names(seq.replace)))
pruned$node.label <- suppressWarnings(as.numeric(pruned$node.label))
pruned$node.label[is.na(pruned$node.label)] <- ""

nwk <- write.tree(pruned)
for (name in names(seq.replace)) {
	re <- paste0("\\b", name, "\\b(:[.0-9e-]+)?")
	nwk <- sub(re, seq.replace[name], nwk)
}
cat(nwk)
