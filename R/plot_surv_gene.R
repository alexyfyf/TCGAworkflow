#' @title Plot survival curve for single gene
#'
#' @description Plot survival curve for single gene
#'
#' @param symbol Character, gene symbol, character
#'
#' @param anno Dataframe, gene annotation file, output from TCGAbiolinks
#'
#' @param count Matrix, gene count matrix, output from TCGAbiolinks
#'
#' @param surv Dataframe, survival data
#'
#' @param path Character, path to plot
#'
#' @import tidyverse
#'
#' @import survival
#'
#' @import survminer
#'
#' @import edgeR
#'
#' @import stats
#'
#' @import magrittr
#'
#' @importFrom rlang .data
#'
#' @importFrom ggplot2 ggsave
#'
#' @import utils
#'
#' @return summary statistics and plot
#'
#' @examples
#' chol <- data_download("TCGA-CHOL", datatype="RNA-seq")
#' x <- chol$x
#' survinfo <- chol$surv
#' plot_surv_gene("TET2", x$genes, x$counts, survinfo, "./")
#'
#' @export plot_surv_gene

## INPUT
## symbol: character of gene symbols
## anno: annotation of genes, with these columns: ensembl_gene_id, external_gene_name
## count: RNA-seq raw count matrix, must be integers, rownames is gene id or symbol, colnames is patient id
## surv: survival data with below columns:  barcode shortLetterCode os.status os.time tumor.stage
## path: the directory to save figures and summary


plot_surv_gene <- function(symbol, anno, count, surv, path){
  # library(tidyverse)
  # library(survminer)
  # library(survival)
  # library(edgeR)

  gene_id <- anno$ensembl_gene_id[match(symbol, anno$external_gene_name)]

  lcpm.sub <-  cpm(count, log=T)[gene_id,]

  idx <- match(surv$barcode, names(lcpm.sub))
  median <-  median(lcpm.sub[idx])
  highlogi <- lcpm.sub[idx] > median
  stopifnot(all.equal(as.character(surv$barcode), names(lcpm.sub)[idx]))
  surv$highlogi <- highlogi
  chitest <-round(chisq.test(highlogi,surv$tumor.stage)$p.value,4)
  # print(chitest)
  # diff <- survdiff(Surv(.data$os.time,.data$os.status)~.data$highlogi,data = surv)
  diff <- survdiff(Surv(surv$os.time,surv$os.status)~surv$highlogi,data = surv)
  pvalue <- round(1-pchisq(diff$chisq,df=1),3)
  # print(pvalue)


  # coxfit <- coxph(Surv(.data$os.time, .data$os.status)~.data$highlogi,data = surv)
  coxfit <- coxph(Surv(surv$os.time, surv$os.status)~surv$highlogi,data = surv)
  cox.zph.fit <-cox.zph(coxfit)
  coxpvalue <- round(cox.zph.fit$table[3],4)
  # ggcoxzph(cox.zph.fit)
  # print(colnames(surv1)[j])
  # print(paste("Cox PH Model P value",coxpvalue,sep = " "))
  # browser()
  # fitsurv <- survfit(Surv(.data$os.time,.data$os.status)~.data$highlogi,data = surv)
  fitsurv <- surv_fit(Surv(surv$os.time,surv$os.status)~surv$highlogi,data = surv)
  pvalue_fh <- round(surv_pvalue(fitsurv, method = "FH_p=1_q=1", data = surv)$pval,4)
  # print(paste("Fleming-Harrington P value",pvalue1,sep = " "))
  # pvalue2 = round(surv_pvalue(fit)$pval,4)
  # pvalue2 = round(surv_pvalue(fit,method = "FH_p=1_q=1")$pval,4)
  # browser()
  ggsurv <- ggsurvplot(
    fitsurv, # fitted survfit object
    data = surv,
    risk.table  = FALSE, # include risk table?
    conf.int    = FALSE, # add confidence intervals?
    pval        = TRUE, # add p-value to the plot?
    pval.method = TRUE, # write the name of the test
    # that was used compute the p-value?
    pval.method.coord = c(5, 0.1), # coordinates for the name
    pval.method.size = 4,          # size for the name of the test
    log.rank.weights = "FH_p=1_q=1"# type of weights in log-rank test
  )
  ggsave(paste(path, symbol,".png",sep = ""),device = "png", width = 6, height = 5)
  # browser()
  surv.summary <- c(symbol, chitest, pvalue, summary(fitsurv)$table[1,'median'],
                 summary(fitsurv)$table[2,'median'], coxpvalue, pvalue_fh)
  # browser()

  names(surv.summary) <- c("gene","chi-square","survival","median time(low)","median time(high)","Cox-HP P value","F-H P value")

  write.csv(surv.summary,paste(path, "survival-summary.csv", sep = "" ))
  return(surv.summary)
}

