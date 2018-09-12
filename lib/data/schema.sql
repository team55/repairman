CREATE TABLE tasks(
    id INTEGER UNIQUE,
    servstatus INTEGER,
    dobefore DATETIME,
    pps_terminal_id INTEGER,
    terminal_break_name TEXT,
    route_priority INTEGER,
    info TEXT,
    mark_latitude DECIMAL,
    mark_longitude DECIMAL,
    executionmark_ts DATETIME,
    inv_num TEXT,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0,

    is_seen INTEGER DEFAULT 0
);
CREATE TABLE terminals(
    id INTEGER UNIQUE,
    code TEXT,
    address TEXT,
    lastactivitytime DATETIME,
    lastpaymenttime DATETIME,
    errortext TEXT,
    src_system_name TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    mobileop TEXT,
    terminalId INTEGER,
    monday INTEGER,
    monday_begin INTEGER,
    monday_end INTEGER,
    tuesday INTEGER,
    tuesday_begin INTEGER,
    tuesday_end INTEGER,
    wednesday INTEGER,
    wednesday_begin INTEGER,
    wednesday_end INTEGER,
    thursday INTEGER,
    thursday_begin INTEGER,
    thursday_end INTEGER,
    friday INTEGER,
    friday_begin INTEGER,
    friday_end INTEGER,
    saturday INTEGER,
    saturday_begin INTEGER,
    saturday_end INTEGER,
    sunday INTEGER,
    sunday_begin INTEGER,
    sunday_end INTEGER,
    exclude INTEGER,
    closed_days_begin DATETIME,
    closed_days_end DATETIME,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE components(
    id INTEGER UNIQUE,
    name TEXT,
    serial TEXT,
    component_group_id INTEGER,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE component_groups(
    id INTEGER UNIQUE,
    name TEXT,
    is_manual_replacement INTEGER,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE repairs(
    id INTEGER UNIQUE,
    name TEXT,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE defects(
    id INTEGER UNIQUE,
    name TEXT,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE task_defect_links(
    task_id INTEGER,
    defect_id INTEGER,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE task_repair_links(
    task_id INTEGER,
    repair_id INTEGER,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE terminal_component_links(
    task_id INTEGER,
    comp_id INTEGER,
    component_group_id INTEGER,

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
CREATE TABLE locations(
    latitude  DECIMAL(18,10),
    longitude DECIMAL(18,10),
    accuracy  DECIMAL(18,10),
    altitude  DECIMAL(18,10),

    local_ts DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_id INTEGER PRIMARY KEY,
    local_inserted INTEGER DEFAULT 0,
    local_updated INTEGER DEFAULT 0,
    local_deleted INTEGER DEFAULT 0
);
