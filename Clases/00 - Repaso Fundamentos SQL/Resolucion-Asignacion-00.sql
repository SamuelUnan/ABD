Create Database ConcessionaireDB

Use ConcessionaireDB

CREATE TABLE Cat_Brand (
    brand_id INT IDENTITY(1,1) NOT NULL,
    brand_name VARCHAR(50) NOT NULL,
    brand_country VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Brand PRIMARY KEY (brand_id),
    CONSTRAINT UQ_Brand_Name UNIQUE (brand_name)
);

CREATE TABLE Cat_Model (
    model_id INT IDENTITY(1,1) NOT NULL,
    brand_id INT NOT NULL,
    model_name VARCHAR(50) NOT NULL,
    model_year SMALLINT NOT NULL,
    model_category VARCHAR(30) NOT NULL,
    model_price DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Model PRIMARY KEY (model_id),
    CONSTRAINT FK_Brand_Model FOREIGN KEY (brand_id) REFERENCES Cat_Brand(brand_id),
    CONSTRAINT UQ_Model_Brand_Name UNIQUE (brand_id, model_name),
    CONSTRAINT CK_Model_Year CHECK (model_year BETWEEN 1990 AND YEAR(GETDATE()) + 1),
    CONSTRAINT CK_Model_Price CHECK (model_price > 0)
);

CREATE TABLE Cat_Vehicle (
    vehicle_id INT IDENTITY(1,1) NOT NULL,
    model_id INT NOT NULL,
    vehicle_vin CHAR(17) NOT NULL,
    vehicle_color VARCHAR(30) NOT NULL,
    vehicle_mileage INT NOT NULL,
    vehicle_sale_price DECIMAL(12,2) NOT NULL,
    vehicle_state VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Vehicle PRIMARY KEY (vehicle_id),
    CONSTRAINT FK_Vehicle_Model FOREIGN KEY (model_id) REFERENCES Cat_Model(model_id),
    CONSTRAINT UQ_Vehicle_Vin UNIQUE (vehicle_vin),
    CONSTRAINT DF_Vehicle_Mileage DEFAULT 0 FOR vehicle_mileage,
    CONSTRAINT DF_Vehicle_State DEFAULT 'Available' FOR vehicle_state,
    CONSTRAINT CK_Vehicle_Mileage CHECK (vehicle_mileage >= 0),
    CONSTRAINT CK_Vehicle_State CHECK (vehicle_state IN ('Available', 'Quoted', 'Sold', 'Delivered')), --Disponible Cotizado Vendido Entregado
    CONSTRAINT CK_Vehicle_Price CHECK (vehicle_sale_price > 0)
);

CREATE TABLE Cat_Accessory (
    accessory_id INT IDENTITY(1,1) NOT NULL,
    accessory_name VARCHAR(50) NOT NULL,
    accessory_price DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Accessory PRIMARY KEY (accessory_id),
    CONSTRAINT UQ_Accessory_Name UNIQUE (accessory_name),
    CONSTRAINT CK_Accessory_Price CHECK (accessory_price > 0)
);

CREATE TABLE Cat_Category (
    category_id INT IDENTITY(1,1) NOT NULL,
    category_name VARCHAR(50) NOT NULL,
    category_description VARCHAR(200) NULL,
    CONSTRAINT PK_Category PRIMARY KEY (category_id),
    CONSTRAINT UQ_Category_Name UNIQUE (category_name)
);

CREATE TABLE Cat_SparePart (
    spare_part_id INT IDENTITY(1,1) NOT NULL,
    category_id INT NOT NULL,
    spare_part_name VARCHAR(50) NOT NULL,
    spare_part_stock INT NOT NULL,
    spare_part_price DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_SparePart PRIMARY KEY (spare_part_id),
    CONSTRAINT FK_Category_SparePart FOREIGN KEY (category_id) REFERENCES Cat_Category(category_id),
    CONSTRAINT DF_SparePart_Stock DEFAULT 0 FOR spare_part_stock,
    CONSTRAINT CK_SparePart_Stock CHECK (spare_part_stock >= 0),
    CONSTRAINT CK_SparePart_Price CHECK (spare_part_price > 0)
);

CREATE TABLE Cat_Branch (
    branch_id INT IDENTITY(1,1) NOT NULL,
    branch_name VARCHAR(50) NOT NULL,
    branch_address VARCHAR(150) NOT NULL,
    branch_city VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Branch PRIMARY KEY (branch_id),
    CONSTRAINT UQ_Branch_Name UNIQUE (branch_name)
);

CREATE TABLE Cat_Client (
    client_id INT IDENTITY(1,1) NOT NULL,
    client_cedula VARCHAR(20) NOT NULL,
    client_name VARCHAR(50) NOT NULL,
    client_lastname VARCHAR(50) NOT NULL,
    client_phone VARCHAR(20) NULL,
    client_email VARCHAR(100) NULL,
    client_address VARCHAR(150) NULL,
    client_registration_date DATE NOT NULL,
    CONSTRAINT PK_Client PRIMARY KEY (client_id),
    CONSTRAINT UQ_Client_Cedula UNIQUE (client_cedula),
    CONSTRAINT UQ_Client_Email UNIQUE (client_email),
    CONSTRAINT DF_Client_RegistrationDate DEFAULT CAST(GETDATE() AS DATE) FOR client_registration_date
);

CREATE TABLE Cat_Employee (
    employee_id INT IDENTITY(1,1) NOT NULL,
    branch_id INT NULL,
    boss_id INT NULL,
    employee_name VARCHAR(50) NOT NULL,
    employee_position VARCHAR(50) NOT NULL,
    employee_salary DECIMAL(12,2) NOT NULL,
    employee_hire_date DATE NOT NULL,
    CONSTRAINT PK_Employee PRIMARY KEY (employee_id),
    CONSTRAINT FK_Branch_Employee FOREIGN KEY (branch_id) REFERENCES Cat_Branch(branch_id),
    CONSTRAINT FK_Employee_Boss FOREIGN KEY (boss_id) REFERENCES Cat_Employee(employee_id),
    CONSTRAINT CK_Employee_Salary CHECK (employee_salary > 0),
    CONSTRAINT DF_Employee_HireDate DEFAULT CAST(GETDATE() AS DATE) FOR employee_hire_date
);

INSERT INTO Cat_Brand (brand_name, brand_country) VALUES
('Toyota', 'Japan'),
('Ford', 'United States');

INSERT INTO Cat_Branch (branch_name, branch_address, branch_city) VALUES
('Managua Norte', 'Carretera Norte Km 5', 'Managua');

INSERT INTO Cat_Client (client_cedula, client_name, client_lastname, client_phone, client_email)
VALUES ('001-010190-0001A', 'Maria', 'Lopez', '8888-0001', 'maria.lopez@mail.com');