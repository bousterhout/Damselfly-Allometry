Damselfly Allometry
================

## Data Preparation

All data prep steps happen in the DataSteps.R file. If you have any
questions it’s pretty well annotated.

``` r
source('DataSteps.R')
```

There are a few different ways you could analyze the data. Here’s what
I’ve tried so far.

## Option 1: Phylogenetic conservatism analysis

Initially it seemed like a good idea to control for relatedness and/or
to look at whether more closely related species had similar growth
responses. Unfortunately, we don’t have enough species to pull that off
(either within a region or shared across regions).

## Option 2: Analyze all data in 1 model

One way to go about this is to include all the lakes in one model and to
include region as a covariate. The downside to this approach is only

``` r
table(df$Species, df$Region)
```

    ##            
    ##             NorthCentral SouthCentral   NE
    ##   ENBA                 0         1340    0
    ##   ENCI                 0            3    0
    ##   ENEX                 0         1566   35
    ##   ENEB_ENHA          468            0  858
    ##   ENGE               794           76  346
    ##   ENSI              1462         3105  100
    ##   ENTR               148         2763    1
    ##   ENVE              1391         2356  507
    ##   ENVERN              56            0   66
    ##   ENAS                 0            0    2
    ##   ENDI                 0            0  271
    ##   ENMI                 0            0   30
    ##   ENPI                 0            0   57

## Including Plots

You can also embed plots, for example:

![](Analysis_Markdown_files/figure-gfm/pressure-1.png)<!-- -->

Note that the `echo = FALSE` parameter was added to the code chunk to
prevent printing of the R code that generated the plot.
