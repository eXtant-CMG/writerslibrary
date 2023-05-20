# Bibundina: a Writer's Library App

Bibundina is a writer's library application that provides an environment for creating and publishing an edition of a collection of books and the reading traces in them. This edition can contain not only the bibliographic details of the books, but also focus on the marginalia left by writers and include information about the provenance of the books and when they were read.

## Requirements
 - [eXist-db](https://github.com/eXist-db/exist) version 5.3.1 or later
 - Java8

## Installation
 - Download the xar file under "releases".
 - Upload it to eXist-db via the package manager.

## Usage
To input data into the app, open the files `/db/writerslibrarary/data/library/library.xml` (the database) and `/db/writerslibrarary/data/library/config.xml` (a configuration file) in the eXide IDE that comes with every eXist-db installation. To edit, you need to be logged in as a DBA in eXist-db.
