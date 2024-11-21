# Fraud Detection in E-Commerce Transactions: A DevOps Team's Approach to ML Integration

## Business Scenario

The e-commerce DevOps team is exploring the implementation of a machine learning model to provide automatic insights into identifying fraudulent transactions on the platform. With an increasing number of transactions, detecting anomalies manually has become inefficient. The team is considering three models for anomaly detection:

- **Isolation Forests**: A tree-based model that isolates anomalies efficiently.
- **Clustering with DBSCAN**: A density-based clustering approach that identifies regions of high density and isolates points in sparse regions as anomalies.
- **Autoencoders**: Neural networks designed to reconstruct input data, where anomalies result in higher reconstruction errors.

The goal is to evaluate these models, compare their performance, and decide on the most effective approach to integrate into the application.  

## Instructions

### Steps 
1. Deploy the application to the target production env.


- **Model Selection**   

   1. Based on our dataset, we don't have labels for the data; therefore, we need to use an unsupervised machine learning model.
   2. Comparing the three given models, the isolation forest model is better suited for large datasets. Clustering with DBSCAN may not perform well for this dataset.
   3. I selected an autoencoder model for training because it has the ability to learn features using a deep neural network.

- **Tuning and Testing**  
   1. I tuned the model by adjusting the number of neurons in each layer and also decreased the batch size and learning rate. Theoretically, this can improve detection accuracy or feature learning, but in this case, the improvement was not significant.  

   ![Alt text](image-3.png)

   2. I also investigated the features in the dataset. The attribute "card_number" could reflect fraud in some sense, so I decided not to drop that column, but instead transform it into a count. By adding more features to the data, the loss decreased from 0.64 to 0.47, as shown below. However, the anomaly detection results did not change. While the loss is a metric for the model, it may not reflect improvement for individual instances.  

   ![Alt text](image-2.png)  

   3. I also tried adding another feature, "name_on_card," to investigate its effect on detection. It caused the loss to increase, so I dropped it.  

   ![Alt text](image-1.png)   

   4. I experimented with the threshold for reconstruction error, finding that reducing the threshold resulted in more transactions being identified as anomalies. A 95th percentile threshold seemed reasonable.

         ![Alt text](image-4.png)


- **Results**  

Applying the autoencoder model to the test dataset, I detected 53 cases of fraud.

   ![Alt text](image-2.png)  

Results for the isolation forest model:

   ![Alt text](image-5.png)

- **Integration into Application UI**  
   Propose how this model could be integrated into the current application UI for admins.
