#!/usr/bin/Rscript

if (!("ape" %in% rownames(installed.packages()))) {
	write("ape package not installed", stderr())
	quit(status=1)
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
	write("Use as follows:", stderr())
	write("pruneCluster.R tree.file cluster.file", stderr())
	quit(status=1)
}

library(ape)

tree.file <- args[1]
clst.file <- args[2]

tree <- read.tree(tree.file)
clst <- read.table(clst.file, sep = "\t", header = F, col.names = c("num","len","name","pct"))
tree$edge.length <- NULL
tree <- drop.tip(tree, setdiff(tree$tip.label, clst$name))
cat(write.tree(tree))
