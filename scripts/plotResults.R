library(ggplot2)

compareMethods <- function(methodA, methodAName, methodB, methodBName) {

  numLabels = ncol(methodA)

  Region = factor(colnames(methodA))

  RegionB = factor(colnames(methodB))

  if ( !(all.equal(Region,RegionB)) ) {
    stop("Region labels are not identical for both methods")
  }

  p = vector("numeric", numLabels)
  t = vector("numeric", numLabels)
  q = vector("numeric", numLabels)
  e = vector("numeric", numLabels)

  for (i in 1:numLabels) {
    x = t.test(methodA[,i], methodB[,i], paired = T)
    p[i] = x$p.value
    t[i] = x$statistic
    e[i] = x$estimate
  }

  q = p.adjust(p, method = "fdr")

  which(q < 0.05)

  methodAMeans = colMeans(methodA)
  methodASD = apply(methodA, 2, sd)

  methodBMeans = colMeans(methodB)
  methodBSD = apply(methodB, 2, sd)

  dfBarsA = data.frame(Region = factor(colnames(methodA)), Mean = methodAMeans, SD = methodASD, Algorithm = rep(methodAName, numLabels))
  dfBarsB = data.frame(Region = factor(colnames(methodB)), Mean = methodBMeans, SD = methodBSD, Algorithm = rep(methodBName, numLabels))

  dfBars = rbind(dfBarsA, dfBarsB)

  dfTTest = data.frame(Region = Region, estimate = e, t.stat = t, p.value = p, fdrq.value = q)

  return(list(tTestData = dfTTest, barPlotData = dfBars))

}



plotMethods <- function(barPlotData) {

  ggplot(data=barPlotData, aes(x=Region, y=Mean, fill=Algorithm)) +
    geom_bar(stat="identity", position=position_dodge()) +
    scale_fill_brewer(palette="Paired") +
    geom_errorbar(aes(ymin=Mean-SD, ymax=Mean+SD), width=.2, position=position_dodge(.9)) +
    theme_minimal() + coord_flip() + ylab("Mean Dice")

}

## Baseline data using ANTs and greedy with mostly defaults
antsRegAntsJLFDice = read.csv("stats/antsRegGreedyJLFDiceBilateral.csv", row.names = 1)
greedyRegGreedyJLFDice = read.csv("stats/greedyRegGreedyJLFDiceBilateral.csv", row.names = 1)

greedyExperimentalDice = read.csv("stats/greedyExperimentalDiceBilateral.csv", row.names = 1)


## Plot cortical labels separately
dfBarsCorticalIndices = c(15:63,78:126)
dfBarsSubCorticalIndices = c(1:14,64:77)

antsVsGreedy = compareMethods(antsRegAntsJLFDice, "ANTs", greedyExperimentalDice, "GreedyExp")

plotMethods(antsVsGreedy$barPlotData[dfBarsSubCorticalIndices,])
plotMethods(antsVsGreedy$barPlotData[dfBarsCorticalIndices,])

greedyCompareParams = compareMethods(greedyRegGreedyJLFDice, "Greedy", greedyExperimentalDice, "GreedyExp")
plotMethods(greedyCompareParams$barPlotData[dfBarsCorticalIndices,])

