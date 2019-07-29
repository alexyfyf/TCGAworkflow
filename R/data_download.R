#' @title Download TCGA data from API
#'
#' @description Download TCGA data from API
#'
#' @param cohort TCGA_CHOL
#'
#' @param datatype RNA-seq
#'
#' @return NULL
#'
#' @examples data_download("TCGA_CHOL", datatype="RNAseq)
#'
#' @export data_download

## data downloading and preprocessing

data_download <- function(cohort, datatype="RNAseq"){
  library(TCGAbiolinks)
  library(tidyverse)
  library(SummarizedExperiment)
  library(edgeR)

  # download TCGA data
  # View(getGDCprojects())
  # by default download RNA-seq HT-seq count matrix
  if (tolower(datatype) %in% c("rnaseq", "rna-seq")) {
    query = GDCquery(cohort, data.category = "Transcriptome Profiling",
                     data.type = "Gene Expression Quantification",
                     workflow.type = "HTSeq - Counts")
  }

  GDCdownload(query, method = "api", files.per.chunk = 10)
  data <- GDCprepare(query)

  ## get expression matrix and clinical data frame

  exp <- assay(data)
  clinical <- colData(data)
  gene <- rowData(data)

  # examine clinical information and remove incomplete ones
  gender <- clinical$gender
  temp <- clinical[!is.na(clinical$gender),]
  exp2 <- exp[,match(as.character(temp$barcode),colnames(exp))]

  clinical2 <- clinical[temp$barcode,]

  os.status = clinical2$vital_status
  os.time = NULL
  i=1
  for(i in 1:length(os.status)) {
    os.time[i] = ifelse(os.status[i] %in% c("Alive","alive"),
                        clinical2$days_to_last_follow_up[i],
                        clinical2$days_to_death[i])
  }

  ## convert tumor stage to numeric
  tumor.stage = as.character(clinical2$tumor_stage)
  tumor.stage <- gsub(".*iv.*",4,tumor.stage,perl = T)
  tumor.stage <- gsub(".*iii.*",3,tumor.stage,perl = T)
  tumor.stage <- gsub(".*ii.*",2,tumor.stage,perl = T)
  tumor.stage <- gsub(".*i.*",1,tumor.stage,perl = T)
  tumor.stage <- gsub("not reported",0,tumor.stage,perl = T)
  length(tumor.stage)
  tumor.stage = factor(tumor.stage)

  # data into DGElist container

  x= DGEList(counts = exp2,genes = data.frame(gene))

  survdata = data.frame(clinical2$barcode,clinical2$shortLetterCode,os.status,os.time,tumor.stage)
  survdata = survdata %>% filter(clinical2.shortLetterCode!="NT")
  survdata$os.status = survdata$os.status %in% c("Dead","dead")

  return(list(x=x, surv=survdata))
}

