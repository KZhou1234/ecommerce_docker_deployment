# -*- coding: utf-8 -*-
"""forests_model.ipynb

Automatically generated by Colab.

Original file is located at
    https://colab.research.google.com/drive/1j7mTQclkh4yx7sBIjsICCxNbo0hw7OLN
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import LabelEncoder, StandardScaler

import sqlite3

conn = sqlite3.connect('db.sqlite3')
data = pd.read_sql_query("SELECT * FROM account_stripemodel", conn)
conn.close()
# Preprocessing
# Drop unnecessary columns and only keep numerical or encoded categorical features
# Hve the card id, address city on the file: 'card_id','address_city', 
data = data.drop(['id', 'address_country', 'name_on_card','address_country'], axis=1)
print(data.columns)

# Convert categorical features to numerical using Label Encoding
label_encoder = LabelEncoder()
for column in ['address_state']:
    data[column] = label_encoder.fit_transform(data[column])
    
for column in ['address_city']:
    data[column] = label_encoder.fit_transform(data[column])
    
#Frequency Encoding: Replace categorical values with their frequency counts.
data['card_id_freq'] = data.groupby('card_id')['card_id'].transform('count')
data.drop(columns=['card_id'], inplace=True)

#encoding and drop
data['email_domain'] = data['email'].apply(lambda x: x.split('@')[-1])
data['email_domain_freq'] = data.groupby('email_domain')['email_domain'].transform('count')

data.drop(columns=['email'], inplace=True)
data.drop(columns=['email_domain'], inplace=True)


data['card_user_count'] = data.groupby('card_number')['user_id'].transform('count')

data['customer_id_count'] = data.groupby('customer_id')['user_id'].transform('count')
data.drop(columns=['customer_id'], inplace=True)

# Create a 'potential_fraud' column and initialize it to 0
data['potential_fraud'] = 0

# Flag rows with NaN values as potential fraud
data.loc[data.isnull().any(axis=1), 'potential_fraud'] = 1

# Remove rows with NaN values
data = data.dropna()

# Normalize the data
scaler = StandardScaler()
data_scaled = scaler.fit_transform(data)

# Build and Train the Isolation Forest
iso_forest = IsolationForest(contamination=0.05, random_state=42)  # 5% contamination rate
iso_forest.fit(data_scaled)

# Predict anomalies
anomaly_labels = iso_forest.predict(data_scaled)
data['anomaly'] = anomaly_labels

# Combine potential fraud and anomaly flags
data['fraud'] = data['potential_fraud'] | (data['anomaly'] == -1)  # Using bitwise OR

# Identify fraudulent transactions
fraudulent_transactions = data[data['fraud'] == 1]

print("Number of fraudulent transactions detected:", len(fraudulent_transactions))
fraudulent_transactions

test_data = pd.read_csv('../AI_Concentration/account_stripemodel_fraud_data.csv')
test_data = test_data.drop(['id', 'card_id', 'customer_id', 'address_country'], axis=1)

