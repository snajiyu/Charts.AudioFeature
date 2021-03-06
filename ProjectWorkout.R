---
  output:
  pdf_document: default
html_document: default
---
  
## Appendix C: Code

library(tidyverse)
library(caret)
library(leaps)
library(gridExtra)
library(cowplot)
library(corrplot)
library(reshape2)
library(ggplot2)
library(car)
library(glmnet)
library(GGally)
library(olsrr)
library(ggcorrplot)
library(knitr)



#Loading preprocessed dataset
data  <- read.csv(file = "hot-100/hot_merged_full.csv",
                  header = TRUE,
                  sep = ",",
                  dec = ".")

data <- filter(data, year > 2007)


### EXPLORATORY DATA ANALYSIS ####
#check where most missing data are across years in the data set
rows_missing <- data[!complete.cases(data), ] %>% ggplot() +
  geom_bar(aes(x=year),width = 1, color = 'white', fill = 'gray18') + theme_bw() +
  labs(title = "Songs with missing values by year")

#most of the missing data is audio features so their unavailability for older songs makes sense.
#Removing rows with missing audio features not a big impact on our response variable either.


#plot distribution of response
weeks_full <- ggplot(data['weeks'], aes(x=weeks)) + 
  geom_histogram(bins = 20, alpha = 0.9, color = "white", fill = "gray18", binwidth = 3) + 
  theme_bw() +
  labs(title = "Distribution of weeks")


#plot distribution of response with transformation
weeks_log <- ggplot((data %>% 
                       dplyr::select(weeks)), aes(x = log(weeks))) +
  geom_histogram(alpha = 0.9, color = "white", fill = "black", bins = 20) +
  theme_bw() +
  labs(title = "Distribution of log(weeks)")

#distribution of weeks by years
weeks_years <-ggplot(data=data, aes(x=as.factor(year), y=weeks))  + 
  geom_boxplot(color='black') + theme_bw() + coord_flip()

#Removing rows with missing values
data <- data %>% na.omit()

#Fixing data type for some columns
data <- data %>% 
  mutate(st_explicit = as.factor(data$st_explicit)) %>%
  mutate(mode = as.factor(data$mode)) %>% 
  mutate(has_feat = as.factor(data$has_feat))

#dropping irrelevant columns as per proposal
data <- data %>%
  dplyr::select(-c('songid','entry_weekid','performer',
                   'st_popularity','pop','rock','country','hiphop','r.b','dance',
                   'feat_artist'))


## Plots for relationships with categorical data
bxplt1 <- ggplot(data=data) +
  geom_boxplot(aes(x=factor(entry_month, levels = month.name), y=weeks)) + 
  theme_bw() +
  coord_flip() + 
  labs(x = "Entry Month", y = "Weeks");

bxplt2 <-ggplot(data=data) + 
  geom_boxplot(aes(x=genre, y=weeks)) + 
  theme_bw() +
  coord_flip() + 
  labs(x = "Genre", y = "Weeks");

bxplt3 <-ggplot(data=data) + 
  geom_boxplot(aes(x=has_feat, y=weeks)) + 
  theme_bw() +
  coord_flip() + 
  labs(x = "has_feat", y = "Weeks");

bxplt4 <-ggplot(data=data) +
  geom_boxplot(aes(x=st_explicit, y=weeks)) +
  theme_bw() +
  coord_flip() + 
  labs(x = "Explicit", y = "Weeks");

bxplt5 <-ggplot(data=data) +
  geom_boxplot(aes(x=mode, y=weeks)) + 
  theme_bw() +
  coord_flip() + 
  labs(x = "Mode", y = "Weeks");

bxplt6 <-ggplot(data=data) + 
  geom_boxplot(aes(x=as.factor(key), y=weeks)) + 
  theme_bw() +
  coord_flip() + 
  labs(x = "Key", y = "Weeks");

#correlation between quantitative independent variables and response
corr_plt <- data %>% dplyr::select(-c('entry_month','genre',
                                      'has_feat', 'st_explicit',
                                      'mode','key', 'peak')) %>% 
  cor() %>% 
  ggcorrplot(type = 'lower',
             ggtheme = ggplot2::theme_bw, 
             colors = c("maroon4", "white", "royalblue4"), 
             lab = TRUE, lab_size = 2) 

#bivariate plots between response and most correlated variables
qsc_plt1 <- ggplot(data=data, aes(x=yr_chart_ct, y=weeks)) + 
  geom_point(color='black') + theme_bw()
qsc_plt2 <-ggplot(data=data, aes(x=art_prev_100_ct, y=weeks))  + 
  geom_point(color='black') + theme_bw()
qsc_plt3 <-ggplot(data=data, aes(x=speechiness, y=weeks))  + 
  geom_point(color='black') + theme_bw()
qsc_plt4 <-ggplot(data=data, aes(x=acousticness, y=weeks))  + 
  geom_point(color='black') + theme_bw()
qsc_plt5 <-ggplot(data=data, aes(x=valence, y=weeks))  + 
  geom_point(color='black') + theme_bw()
qsc_plt6 <-ggplot(data=data, aes(x=as.factor(year), y=weeks))  + 
  geom_boxplot(color='black') + theme_bw() + coord_flip()




## Train test split
training <- filter(data, year <= 2015)
test <- filter(data, year > 2015)






## INITIAL Model
init.model <- lm(data = data, formula = log(weeks) ~ art_prev_100_ct +
                   yr_chart_ct + valence + acousticness + danceability +
                   speechiness + genre + key + st_explicit)



### FINAL MODEL from Forward selection with AIC and BIC 
#With log transformation
biggest1 = formula(lm(log(weeks) ~ (yr_chart_ct + entry_month +
                                      genre + st_explicit + st_duration_ms + 
                                      danceability + energy + key + loudness +
                                      mode + speechiness + acousticness+ 
                                      instrumentalness + liveness + 
                                      valence + tempo + time_signature +
                                      has_feat + art_prev_100_ct)^2, data = training))

min.model1 = lm(log(weeks) ~ 1, data = training)

fwd.model.AIC1 = step(min.model1,
                      direction = "forward",
                      trace = 0, 
                      scope = biggest1, k = 2)

fwd.model.BIC1 = step(min.model1,
                      direction = "forward", 
                      trace = 0, 
                      scope = biggest1,
                      k = log(nrow(training)))



#Without log transformation
biggest2 = formula(lm(weeks ~ (yr_chart_ct + entry_month + genre +
                                 st_explicit + st_duration_ms +  
                                 danceability + energy + key + loudness + 
                                 mode + speechiness + acousticness+
                                 instrumentalness + liveness + valence + 
                                 tempo + time_signature +
                                 has_feat + art_prev_100_ct)^2, data = training))

min.model2 = lm(weeks ~ 1, data = training)

fwd.model.AIC2 = step(min.model2,
                      direction = "forward",
                      trace = 0, 
                      scope = biggest2, k = 2)

fwd.model.BIC2 = step(min.model2, 
                      direction = "forward", 
                      trace = 0,
                      scope = biggest2,
                      k = log(nrow(training)))




#' @title rmse_cv_loo
#' @description calculates leave one out cross validation error
#' @param model model object
#' @return root mean squared error
rmse_cv_loo <- function(model) {
  cv_mse = mean((resid(model) / (1-hatvalues(model)))^2)
  return(sqrt(cv_mse))
}

fwd.model.AIC1 %>% rmse_cv_loo()
fwd.model.BIC1 %>% rmse_cv_loo()





### FINAL MODEL WITH LASSO APPROACH
modelX <- lm(data=training, formula=biggest1) %>% model.matrix()
lasso.cv <- cv.glmnet(y = log(training$weeks),
                      x = modelX,
                      alpha = 1,
                      family = "gaussian")

best_lambda <- lasso.cv$lambda.min

lasso.model2_tr <- glmnet(y = log(training$weeks),
                          x = modelX,
                          alpha = 1)

lasso.model2 <- glmnet(y = log(training$weeks),
                       x = modelX, 
                       lambda = best_lambda,
                       alpha = 1)

#lasso model predictions on training data
lasso_predictions <- lasso.model2 %>% predict(modelX) %>% as.vector()

#lasso performance metrics
Lasso.RMSE = RMSE(lasso_predictions, log(training$weeks))
Lasso.R2 = R2(lasso_predictions, log(training$weeks))




#get # of regressors in lasso model
coef(lasso.model2) %>% as.matrix() %>% 
  as.data.frame() %>% 
  filter(s0 > 0 | s0 < 0) %>% 
  nrow()




#FINAL MODEL PERFORMANCE PLOTS

BIC_train <- fwd.model.BIC1$fitted.values
BIC_pred <- predict.lm(fwd.model.BIC1, newdata = test)


rmse_train_pred <- round(sqrt(mean((log(training$weeks) - BIC_train)^2)), digits = 2)
rmse_test_pred <- round(sqrt(mean((log(test$weeks) - BIC_pred)^2)), digits = 2)

#Training perfomance plot
bic_plt_train <- ggplot(training, aes(x=BIC_train, y = log(weeks))) + 
  geom_point(color='black') +
  geom_smooth(aes(color = 'BIC Model'), 
              stat = 'smooth', method = 'gam', formula = y ~ s(x, bs = "cs")) +
  geom_line(aes(x=seq(min(BIC_train),max(BIC_train),
                      length.out = length(BIC_train)), 
                y=seq(min(BIC_train),max(BIC_train),
                      length.out = length(BIC_train)), color = 'Ideal')) +
  scale_color_manual(values = c('blue', 'red')) +
  theme(legend.position = "none") +
  theme_bw() + 
  labs(title = "BIC Model Performance on Training Data",
       x = "Predicted log(Weeks)", y = 'Actual log(Weeks)') + 
  annotate(geom = "text", x=1, y=5, 
           label=paste("RMSE : ",rmse_train_pred), color = "red") +
  xlim(0,3) + ylim(0,5)

#Test perfomance plot
bic_plt_test <- ggplot(test, aes(x=BIC_pred,
                                 y = log(weeks))) + geom_point(color='black') +
  geom_smooth(aes(color = 'BIC Model'), 
              stat = 'smooth', method = 'gam', formula = y ~ s(x, bs = "cs")) +
  geom_line(aes(x=seq(min(BIC_pred),max(BIC_pred),
                      length.out = length(BIC_pred)), 
                y=seq(min(BIC_pred),max(BIC_pred),
                      length.out = length(BIC_pred)), color = 'Ideal')) +
  scale_color_manual(values = c('blue', 'red')) +
  theme(legend.position = "none") +
  theme_bw() + 
  labs(title = "BIC Model Performance on Test Data",
       x = "Predicted log(Weeks)", y = 'Actual log(Weeks)') + 
  annotate(geom = "text", x=1, y=5, 
           label=paste("RMSE : ",rmse_test_pred), color = "red") +
  xlim(0,3) + ylim(0,5)




#Show final model performance plots
grid.arrange(bic_plt_train, bic_plt_test, ncol=2)



# Plot Lasso results
par(mfrow=c(1,2))


plot(lasso.cv)
lines(c(log(best_lambda), log(best_lambda)),
      c(-1000, 1000), lty = "dashed", lwd = 3)

plot(lasso.model2_tr, xvar = "lambda")
lines(c(log(best_lambda), log(best_lambda)), 
      c(-1000, 1000), lty = "dashed", lwd = 3)


#Show final model diagnostics plots
par(mfrow=c(2,2))
plot(fwd.model.BIC1)

#show response variable EDA plots
grid.arrange(weeks_full, weeks_log, weeks_years, ncol = 3)


#show response-qualitative relationships plots
grid.arrange(bxplt1, bxplt2, bxplt4, bxplt6, nrow = 1, ncol = 4)


#show response-quantitative relashionship plots
grid.arrange(qsc_plt1, qsc_plt2, qsc_plt3, qsc_plt4, qsc_plt5, nrow=1, ncol=5)


#show quantitative variables correlations plot
corr_plt

