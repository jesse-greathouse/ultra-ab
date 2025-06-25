use ultraab;

CREATE TABLE ab_test_results (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    sid          VARCHAR(36)     NOT NULL,
    bucket       CHAR(1)         NOT NULL,
    did_convert  TINYINT(1)      NOT NULL,
    url          LONGTEXT        NOT NULL,
    created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_sid (sid),
    KEY idx_bucket (bucket),
    KEY idx_did_convert (did_convert),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
