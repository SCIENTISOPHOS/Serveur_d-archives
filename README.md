# 🗄️ VSH — Archive Server

A client-server archive system with a custom shell interface (`vsh`) for creating, browsing, and extracting directory tree archives stored on a remote server.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Archive Format](#archive-format)
- [Usage](#usage)
  - [list](#-list-mode)
  - [create](#-create-mode)
  - [browse](#-browse-mode)
  - [extract](#-extract-mode)
- [Browse Shell Commands](#browse-shell-commands)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Authors](#authors)

---

## Overview

`vsh` is a custom shell command that communicates with a remote archive server. It allows you to:

- List archives stored on the server
- Create an archive from the current local directory tree
- Interactively browse an archive through a dedicated shell
- Extract an archive to restore the original directory tree locally

---

## Archive Format

An archive is a text file that represents a full directory tree along with the content of all its files. It is split into two parts:

### Structure

```
<header_start_line>:<body_start_line>
--- HEADER ---
--- BODY ---
```

### Header

The header lists all directories and their contents, one block per directory:

```
directory <dir_path>
<name> <permissions> <size> [<body_line> <line_count>]
@
```

- **Directories** have no body reference (size only).
- **Non-empty files** include two extra numbers: the starting line in the body and the number of lines they occupy.
- **Empty files** have size `0` and no body reference.

### Body

The body contains the raw text content of all non-empty files, in the order they are referenced in the header.

### Example

```
3:25
directory Exemple\Test\
A drwxr-xr-x 4096
B drwxr-xr-x 4096
toto1 -rwxr-xr-x 29 1 3
toto2 -rw-r--r-- 249 4 10
@
directory Exemple\Test\A
A1 drwxr-xr-x 4096
toto3 -rw-r--r-- 121 14 3
@
...
#!\bin\bash
echo "bonjour!"
NAME
```

---

## Usage

```
vsh -<mode> <server_name> <port> [archive_name]
```

### 📋 List mode

```bash
vsh -list <server_name> <port>
```

Displays the list of all archives available on the server.

---

### 📦 Create mode

```bash
vsh -create <server_name> <port> <archive_name>
```

Creates an archive named `<archive_name>` from the **current local directory tree** and sends it to the server.

---

### 🔍 Browse mode

```bash
vsh -browse <server_name> <port> <archive_name>
```

Opens an interactive `vsh` shell to explore the archive `<archive_name>` on the server.

---

### 📤 Extract mode

```bash
vsh -extract <server_name> <port> <archive_name>
```

Downloads the archive and **restores the full directory tree** (with correct permissions) into the current local directory.

---

## Browse Shell Commands

Once inside the `vsh` interactive shell, the following commands are available:

| Command | Description |
|---|---|
| `pwd` | Print the current directory within the archive |
| `ls [path]` | List contents of the current or specified directory |
| `ls -l [path]` | Detailed listing (permissions, size, name) |
| `ls -a [path]` | Show hidden files |
| `ls -al [path]` | Detailed listing including hidden files |
| `cd <path>` | Navigate to a directory (`cd \` goes to root, `cd ..` goes up) |
| `cat <file...>` | Display the content of one or more files |
| `rm <name>` | Remove a file or directory (recursive if directory) |
| `touch <file>` | Create an empty file if it does not already exist |
| `mkdir <dir>` | Create a directory |
| `mkdir -p <a\b\c>` | Recursively create a nested directory tree |

> **Notes:**
> - In the `vsh` shell, the root `\` corresponds to the archive's top-level directory — it is **not** the Linux root `/`.
> - All commands support both **relative** and **absolute** paths.
> - Error handling follows standard shell behavior (e.g., `cd toto` fails if `toto` is a file or does not exist).

### Example session

```
$ vsh -browse myserver 8080 arch
vsh:> pwd
\
vsh:> ls
 A\  B\  toto1*  toto2
vsh:> cd A
vsh:> ls -l
drwxr-xr-x 4096 A1
drwxr-xr-x 4096 A2
drwxr-xr-x 4096 A3
-rw-r--r-- 121  toto3
vsh:> cat toto1
#!\bin\bash
echo "bonjour!"
```

---

## Project Structure

```
.
├── vsh               # Main client executable
├── server            # Archive server
├── archive/          # (Example) stored archives
├── src/
│   ├── client/       # Client-side logic (vsh command)
│   ├── server/       # Server-side logic
│   └── archive/      # Archive parsing & generation
└── README.md
```

---

## Getting Started

### Prerequisites

- GCC or any C compiler
- Make
- A Unix/Linux environment

### Build

```bash
make
```

### Run the server

```bash
./server <port>
```

### Run the client

```bash
./vsh -list localhost 8080
./vsh -create localhost 8080 my_archive
./vsh -browse localhost 8080 my_archive
./vsh -extract localhost 8080 my_archive
```

---

## Authors

- **[Mahomed Arafat ANJOUENEYA MOUANSIE]** — [GitHub](https://github.com/SCIENTISOPHOS)
- **[Nom 2]** — [GitHub](https://github.com/)

> Project carried out as part of a Systems Programming course at [UTT](https://www.utt.fr).
