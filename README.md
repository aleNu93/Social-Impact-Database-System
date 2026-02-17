# 🧠 Addiction Treatment Follow-Up Management Database

## 📌 Overview
This project implements a relational database designed to support a Follow-Up and Treatment Center for People with Addiction in Costa Rica.  
The system centralizes clinical, administrative, and therapeutic information to improve monitoring, continuity of care, and long-term recovery outcomes.

The database models the complete therapeutic lifecycle:

- 🧩 Prevention and intake
- 🩺 Clinical evaluation and diagnosis
- 💊 Detoxification
- 🧑‍⚕️ Rehabilitation
- 🏫 Social reintegration
- 📊 Short, medium, and long-term follow-up

The goal is to provide structured traceability of each patient's treatment process and enable evidence-based decision making.

---

## 🚀 Features
- 📁 Centralized patient records
- 🧬 Diagnosis tracking using CIE-10 classification
- 🔄 Treatment phase management
- 💊 Medication monitoring
- 🗓 Therapeutic activity tracking
- 👥 Staff assignment management
- 📈 Recovery progress monitoring
- 📊 Analytical and statistical reporting

---

## 🗄 Database Design
The system was modeled using a fully normalized relational structure to ensure consistency and eliminate redundancy.

### Main Entities
- Person
- Patient
- Employee
- Job_Position
- Treatment_Phase
- Diagnosis_CIE10
- Medication
- Activity

### Relationship Tables
- Patient_Phase
- Patient_Diagnosis
- Patient_Activity
- Patient_Activity_Medication
- Person_Activity

---

## ⚙️ Technical Implementation
- Normalization from First Normal Form (1NF) to Third Normal Form (3NF)
- SQL DDL and DML scripting
- Stored procedures for operational workflows
- Triggers for integrity enforcement and automation
- Database views for controlled data access
- Analytical queries for monitoring and reporting
- Cursor-based data processing

---

## 👨‍💻 My Role
I was responsible for the complete design and implementation of the relational database architecture.  
The work included full normalization from 1NF to 3NF, definition of relationships and constraints, and development of stored procedures, triggers, views, and analytical SQL queries to support data integrity, automation, and reporting in a healthcare-focused social impact system.

---

## 🎓 Academic Context
Database Query Language  
III Term, 2025
