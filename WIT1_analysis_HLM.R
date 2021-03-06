# WIT study 1 analysis

library(plyr)
library(dplyr)
library(lme4)
library(ggplot2)
library(car)
library(broom)

# data ingest
dat = read.delim("clean_wit1.txt", stringsAsFactors = F)
# Make Subject a factor
dat = mutate(dat, Subject = as.factor(Subject))

# add columns -- see 7_Study1_Sas-analysis
# this is still WIP, might not need it
dat = dat %>% 
  mutate(TrialType = dplyr::recode(TrialType, 
                                   BlackGun = "Black.Gun", WhiteGun = "White.Gun", NeutralGun = "Neutral.Gun",
                                   BlackTool = "Black.Tool", WhiteTool = "White.Tool", NeutralTool = "Neutral.Tool")) %>% 
  separate(TrialType, c("Cue", "Probe"), sep = "\\.") %>% 
  mutate(Condition = substring(ExperimentName, 5)) %>% # prune "WIT_" prefix
  mutate(ConditionCue = paste(Condition, Cue))

# TODO: Think carefully about these and double-check
# Original SAS script had "neutral_white White" and "neutral_white Neutral" flipped
# this is only for the 3 × 2 × 2, which I think is a bad idea anyway
gunPrimes = c("black_white Black", "neutral_black Black", "neutral_white White")
toolPrimes = c("black_white White", "neutral_black Neutral", "neutral_white Neutral")

dat = dat %>% 
  mutate(CueClass = ifelse(ConditionCue %in% gunPrimes, "Class_A", "Class_B"))

# Make fast-only dataset for accuracy
dat.acc = dat %>% 
  filter(Probe.RT <= 500)
# Make correct-only dataset for speed
dat.rt = dat %>% 
  filter(Probe.ACC == 1)

# Accuracy analysis
# Did I do this wrong? Takes forever to run on my laptop
# Consider role of random slopes.
# See if I can retrieve random stimulus data
# Tweaked algorithm allows convergence
m1 = glmer(Probe.ACC ~ Condition * CueClass * Probe + (1|Subject),
          data = dat.acc, family = "binomial",
          control = glmerControl(optimizer="bobyqa"))
summary(m1)
Anova(m1, type = 3)

# Maximal random model?
m1.full = glmer(Probe.ACC ~ Condition * CueClass * Probe + 
                  (1 + CueClass * Probe|Subject) + (1|CueType) + (1|ProbeType),
           data = dat.acc, family = "binomial",
           control = glmerControl(optimizer="bobyqa"))
summary(m1.full)
Anova(m1.full, type = 3) # wow, seems to converge OK

lsmeans(m1.full, c("Condition", "CueClass", "Probe")) %>% 
          summary()
# Remember Class_A are the hypothesized gun primes
# So for Black/White condition, White Tool - White Gun,
# I want CueClass == Class_B, Condition == black_white
lsmeans(m1.full, c("Condition", "CueClass", "Probe")) %>% 
  contrast(list(WhiteGun.vs.WhiteTool = c(0, 0, 0, 
                                          -1, 0, 0, 
                                          0, 0, 0, 
                                          1, 0, 0)))


# 2x2s within each level of Condition
# These models converge
m2 = dat.acc %>% 
  filter(Condition == "black_white") %>% 
  glmer(Probe.ACC ~ Cue * Probe + (1 + Cue * Probe|Subject),
           data = ., family = "binomial",
        contrasts = list(Cue = "contr.sum",
                         Probe = "contr.sum"))
summary(m2)
Anova(m2, type = 3) 

# White-Gun vs White-Tool
filter(dat.acc, Condition == "black_white", Cue == "White") %>% 
  glmer(Probe.ACC ~ Probe + (1|Subject),
        data = ., family = "binomial",
        contrasts = list(Probe = "contr.sum")) %>% 
  summary()

m3 = dat.acc %>% 
  filter(Condition == "neutral_black") %>% 
  glmer(Probe.ACC ~ Cue * Probe + (1|Subject),
        data = ., family = "binomial",
        contrasts = list(Cue = "contr.sum",
                         Probe = "contr.sum"))
summary(m3)
Anova(m3, type = 3)

m4 = dat.acc %>% 
  filter(Condition == "neutral_white") %>% 
  glmer(Probe.ACC ~ Cue * Probe + (1|Subject),
        data = ., family = "binomial",
        contrasts = list(Cue = "contr.sum",
                         Probe = "contr.sum"))
summary(m4)
Anova(m4, type = 3)

# Could yet implement a cell means model, too.

# Another way of implementing it is to condition on Prime
#  and look for the interactions with Condition
# NB: Condition is between-subjects, do not attempt to model it in random slope

pm1 = dat.acc %>% 
  filter(Cue == "Black") %>% 
  glmer(Probe.ACC ~ Condition * Probe + 
          (1 + Probe|Subject),
        data = ., family = "binomial",
        contrasts = list(Probe = "contr.sum"))
summary(pm1)
Anova(pm1, type = 3) # Not significant, Blacks always prime Gun

pm2 = dat.acc %>% 
  filter(Cue == "White") %>% 
  glmer(Probe.ACC ~ Condition * Probe + 
          (1 + Probe|Subject),
        data = ., family = "binomial",
        contrasts = list(Probe = "contr.sum"))
summary(pm2)
Anova(pm2, type = 3) # Note the big flip, Whites go from priming Gun to Tool

pm3 = dat.acc %>% 
  filter(Cue == "Neutral") %>% 
  glmer(Probe.ACC ~ Condition * Probe + 
          (1 + Probe|Subject),
        data = ., family = "binomial",
        contrasts = list(Probe = "contr.sum"))
summary(pm3)
Anova(pm3, type = 3) 
# Again a big flip, Neutrals prime Tools moreso in neutral-black than neutral-white

# Reaction time analyses

# Condition on Prime and look for the interactions with Condition

pm1.rt = dat.rt %>% 
  filter(Cue == "Black") %>% 
  lmer(Probe.RT ~ Condition * Probe + 
         (1 + Probe|Subject),
       data = .,
       contrasts = list(Probe = "contr.sum"))
summary(pm1.rt)
Anova(pm1.rt, type = 3)
# Slight tendency for stronger black-gun priming in neutral-black vs white-black

pm2.rt = dat.rt %>% 
  filter(Cue == "White") %>% 
  lmer(Probe.RT ~ Condition * Probe + 
         (1 + Probe|Subject),
        data = .,
       contrasts = list(Probe = "contr.sum"))
summary(pm2.rt)
Anova(pm2.rt, type = 3) # Note the big flip from black-white to neutral-white

pm3.rt = dat.rt %>% 
  filter(Cue == "Neutral") %>% 
  lmer(Probe.RT ~ Condition * Probe + 
         (1 + Probe|Subject),
        data = .,
       contrasts = list(Probe = "contr.sum"))
summary(pm3.rt)
Anova(pm3.rt, type = 3) # Not significant, small change

# Now the trick will be formalizing this in some sort of effect size...

# Summary tables
sumTab1 = dat.acc %>% 
  group_by(Condition, Probe, Cue) %>% 
  summarise("M_acc" = mean(Probe.ACC, na.rm = T),
            "SD_acc" = sd(Probe.ACC, na.rm = T),
            "M_rt" = mean(Probe.RT, na.rm = T),
            "SD_rt" = sd(Probe.RT, na.rm = T))

# Export statistical output
dir.create("results")
sink("./results/WIT1_model_output.txt")
cat("Accuracy, overall thingie\n")
Anova(m1, type = 3)
cat("Accuracy, 2x2s\n")
cat("Black-White task\n")
Anova(m2, type = 3)
cat("Black-Neutral task\n")
Anova(m3, type = 3)
cat("Neutral-White task\n")
Anova(m4, type = 3)
cat("Accuracy, analyses by Prime\n")
cat("Black Primes\n")
Anova(pm1, type = 3)
cat("White Primes\n")
Anova(pm2, type = 3)
cat("Neutral Primes\n")
Anova(pm3, type = 3)
# cat("RT, 2x2s")
# cat("Black-White task")
# Anova(m2.rt, type = 3)
# cat("Black-Neutral task")
# Anova(m3.rt, type = 3)
# cat("Neutral-White task")
# Anova(m4.rt, type = 3)
cat("RT, analyses by Prime\n")
cat("Black Primes\n")
Anova(pm1.rt, type = 3)
cat("White Primes\n")
Anova(pm2.rt, type = 3)
cat("Neutral Primes\n")
Anova(pm3.rt, type = 3)
sink()

# Plotting ----
# Consider re-ordering or color-coding or something to emphasize critical comparisons
dat.acc %>% 
  group_by(Subject, Condition, TrialType) %>% 
  summarize(Accuracy = mean(Probe.ACC, na.rm = T)) %>% 
  ggplot(aes(x = TrialType, y = Accuracy)) +
  geom_violin() +
  geom_boxplot(width = .3, notch = T) +
  facet_wrap(~Condition, scales = "free_x")

dat.rt %>% 
  group_by(Subject, Condition, TrialType) %>% 
  summarize(Latency = mean(Probe.RT, na.rm = T)) %>% 
  ggplot(aes(x = TrialType, y = Latency)) +
  geom_violin() +
  geom_boxplot(width = .3, notch = T) +
  facet_wrap(~Condition, scales = "free_x")

# Aggregation and table export
# Should I use conditional trials (dat.acc, dat.rt) or unconditional (dat)?
# I'll use conditional b/c that's what's actually analyzed.
# Another question is whether to first average w/in subjects 
# or just average across all trials directly.
# I think it's better to average w/in subjects first.
S1T1.acc = dat.acc %>% 
  group_by(Condition, TrialType, Subject) %>% 
  summarize(M.sub = mean(Probe.ACC, na.rm = T))%>% 
  summarize(M.acc = mean(M.sub, na.rm = T),
            SD.acc = sd(M.sub, na.rm = T))

S1T1.rt = dat.rt %>% 
  group_by(Condition, TrialType, Subject) %>% 
  summarize(M.sub = mean(Probe.RT, na.rm = T))%>% 
  summarize(M.rt = mean(M.sub, na.rm = T),
            SD.rt = sd(M.sub, na.rm = T))

S1T1 = full_join(S1T1.acc, S1T1.rt)
write.table(S1T1, "S1table.txt", sep = "\t", row.names = F)
