// vmangos-deploy
// Copyright (C) 2023-2024  Michael Serajnik  https://github.com/mserajnik

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <stdio.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

int is_service_running(int port) {
    int sock;
    struct sockaddr_in server;
    const char *host = "127.0.0.1";

    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        return 1;
    }

    server.sin_addr.s_addr = inet_addr(host);
    server.sin_family = AF_INET;
    server.sin_port = htons(port);

    if (connect(sock, (struct sockaddr *)&server, sizeof(server)) < 0) {
        close(sock);
        return 1;
    }

    close(sock);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        return 1;
    }

    int port = 0;
    if (sscanf(argv[1], "%d", &port) != 1 || port < 1 || port > 65535) {
        fprintf(stderr, "Invalid port number.\n");
        return 1;
    }

    return is_service_running(port);
}
