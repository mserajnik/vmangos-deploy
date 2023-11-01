-- vmangos-deploy
-- Copyright (C) 2023-present  Michael Serajnik  https://github.com/mserajnik

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.

-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CREATE DATABASE IF NOT EXISTS mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS characters DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS realmd DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS logs DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
CREATE USER 'mangos'@'localhost' IDENTIFIED BY 'mangos';
SET PASSWORD FOR 'mangos'@'localhost' = PASSWORD('mangos');
GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';
FLUSH PRIVILEGES;
GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;
GRANT ALL ON characters.* TO mangos@'localhost' WITH GRANT OPTION;
GRANT ALL ON realmd.* TO mangos@'localhost' WITH GRANT OPTION;
GRANT ALL ON logs.* TO mangos@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
