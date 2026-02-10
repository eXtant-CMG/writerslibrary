# Bibundina: a Writer's Library App

Bibundina is a writer's library application that provides an environment for creating and publishing an edition of a collection of books and the reading traces in them. This edition can contain not only the bibliographic details of the books, but also focus on the marginalia left by writers and include information about the provenance of the books and when they were read.

## Requirements
 - [eXist-db](https://github.com/eXist-db/exist) version 5.3.1 or later
 - Java8 or later

## Installation
 - Download the xar file under "releases".
 - Upload it to eXist-db via the package manager.

## Usage
After installation, Bibundina opens with a welcome page and loads a sample library collection containing example records that demonstrate the encoding schema. This sample library is fully functional and can be used to encode your own material, but we recommend creating a separate library collection for production use. Bibundina supports working with multiple library collections, and you can switch between them at any time using an admin tools

To input data into the app, create a new library collection and then add book XML files in `/db/apps/writerslibrary/data/your-library/books/` — one file per book, each named after the book's unique ID (e.g., `ARA-LIB.xml`). You can also configure the library by editing `/db/apps/writerslibrary/data/your-library/config.xml`. Both can be opened in the eXide IDE that comes with every eXist-db installation. To edit, you need to be logged in as a DBA in eXist-db.

## Documentation and User Manual
Documentation on how to get started with the writer's library app as an administrator is available in the app but can also be read in [documentation.md](documentation.md). 

A manual geared towards users of the writer's library edition created with the app can be found [here](usermanual.md) as well as in the app itself. 
