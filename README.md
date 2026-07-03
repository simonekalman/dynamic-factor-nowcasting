# Nowcasting US Private Demand

This repository contains the implementation of a mixed-frequency Dynamic Factor Model (DFM) for real-time nowcasting of US Private Demand.

## Overview

The project develops a state-space Dynamic Factor Model estimated via Maximum Likelihood and the Kalman Filter to track US Private Demand in real time using mixed-frequency macroeconomic data.

A central objective is to identify the optimal information set through a systematic variable selection procedure, evaluating both hard and soft indicators according to their contribution to forecasting performance.

## Research Topics

- Macroeconomic Nowcasting
- Dynamic Factor Models
- Mixed-Frequency Data
- State-Space Models
- Kalman Filtering
- Hard and Soft Indicators
- Variable Selection
- Forecast Evaluation

## Methodology

- Stock–Watson Dynamic Factor Model
- State-Space Representation
- Kalman Filter
- Maximum Likelihood Estimation
- Mixed-Frequency Aggregation
- Sequential Variable Selection

## Indicators

The model evaluates a wide set of macroeconomic indicators, including:

- Consumption
- Residential and Non-Residential Investment
- Capital Goods Shipments
- Building Permits
- Industrial Production
- Consumer Sentiment (soft indicator)
- Alternative real-time macroeconomic indicators

## Current Best Model

The preferred specification is selected through an iterative model selection procedure and achieves a correlation of **0.733** between the estimated common factor and US Private Demand.

## Software

- MATLAB

## Author

**Simone Alberto Distefano**  
Barcelona School of Economics
