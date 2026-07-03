# Nowcasting US Private Demand

This repository contains the implementation and documentation of a mixed-frequency Dynamic Factor Model developed to nowcast US Private Demand.

## Overview

The project develops a state-space Dynamic Factor Model estimated via Maximum Likelihood and the Kalman Filter to produce real-time nowcasts of US Private Demand.

A central contribution of the project is the systematic evaluation of alternative macroeconomic indicators through an iterative variable selection procedure, identifying the specification that maximizes forecasting performance while preserving economic interpretability.

## Research Topics

- Macroeconomic Nowcasting
- Dynamic Factor Models
- Mixed-Frequency Data
- State-Space Models
- Kalman Filtering
- Variable Selection
- Forecast Evaluation

## Methodology

- Stock–Watson Dynamic Factor Model
- State-Space Representation
- Kalman Filter
- Maximum Likelihood Estimation
- Mixed-Frequency Aggregation
- Real-Time Nowcasting

## Repository Contents

- MATLAB implementation of the Dynamic Factor Model
- Estimation routines
- Model estimation log documenting all specifications and model selection experiments

## Current Best Specification

The final model achieves a correlation of **0.733** between the estimated common factor and US Private Demand after an iterative variable selection procedure that evaluates alternative indicator sets and model specifications.

## Software

- MATLAB

## Author

**Simone Alberto Distefano**  
Barcelona School of Economics
