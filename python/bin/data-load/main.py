"""
Gene Data Loading Utility.

This module provides functionality to load gene data from CSV files into the
PGNC database. It parses the CSV data and creates appropriate database records
for genes, symbols, names, locations, locus types, and cross-references.

Example usage:
    python main.py --file /path/to/gene_data.csv
"""

import argparse
import gzip
import os
import subprocess

import pandas
import sqlalchemy as sa
from db.config import Config
from db.enum_types.basic_status import BasicStatusEnum
from db.enum_types.gene_status import GeneStatusEnum
from db.enum_types.nomenclature import NomenclatureEnum
from db.insert.gene_name import GeneName
from db.insert.gene_symbol import GeneSymbol
from db.insert.gene_xref import GeneXref
from db.models.external_resource import ExternalResource
from db.models.gene import Gene
from db.models.gene_has_location import GeneHasLocation
from db.models.gene_has_locus_type import GeneHasLocusType
from db.models.gene_has_name import GeneHasName
from db.models.gene_has_symbol import GeneHasSymbol
from db.models.gene_has_xref import GeneHasXref
from db.models.location import Location
from db.models.locus_type import LocusType
from db.models.name import Name
from db.models.symbol import Symbol
from db.models.user import User
from db.models.xref import Xref


class GeneDataLoader:
    """
    A class to handle loading and parsing gene data from a CSV file.

    This class provides methods to read gene data from a CSV file,
    parse it into a pandas DataFrame, and process the data to create
    appropriate database records.

    Attributes:
        file_path (str): Path to the CSV file containing gene data.
        df (pandas.DataFrame): DataFrame containing the parsed gene data.
    """

    def __init__(self, file_path):
        """
        Initializes the GeneDataLoader with the path to the CSV file.

        Args:
            file_path (str): Path to the CSV file.
        """
        self.file_path = file_path
        self.df = self.parse_csv()

    def parse_csv(self):
        """
        Parses the CSV file and extracts gene-related data into a pandas
        DataFrame.

        Returns:
            pandas.DataFrame or None: A DataFrame containing the parsed data,
            or None if an error occurs.

        Raises:
            FileNotFoundError: If the specified file is not found.
            pandas.errors.EmptyDataError: If the CSV file is empty.
            pandas.errors.ParserError: If the CSV file cannot be parsed.
        """
        try:
            df = pandas.read_csv(
                self.file_path, dtype=str, na_values=["NA", ""], keep_default_na=False
            )
            print("Successfully read CSV file into a DataFrame.")
            return df
        except FileNotFoundError:
            print(f"Error: File not found at path: {self.file_path}")
            return None
        except pandas.errors.EmptyDataError:
            print("Error: The CSV file is empty.")
            return None
        except pandas.errors.ParserError:
            print("Error: Failed to parse the CSV file. It may be malformed.")
            return None

    def process_data(self):
        """
        Processes the gene data loaded from the CSV file.

        This method orchestrates the overall data processing flow by iterating through
        each row of the DataFrame and delegating specific gene-related information
        processing to specialized methods.

        Raises:
            ValueError: If required data fields are missing.
        """
        if self.df is None:
            print("No data to process. Ensure the CSV file was loaded correctly.")
            return

        engine = sa.create_engine(Config.DATABASE_URI)
        try:
            for index, row in self.df.iterrows():
                print("--" * 20)
                print("Processing row...")
                self._process_row(engine, index, row)
            print("Data processing complete.")
        finally:
            engine.dispose()

    def _process_row(self, engine, index, row):
        """
        Process a single row of gene data.

        Args:
            engine (sqlalchemy.engine.Engine): SQLAlchemy database engine.
            index (int): Index of the current row.
            row (pandas.Series): The DataFrame row containing gene data.

        Returns:
            bool: True if processing succeeded, False if the row was skipped.
        """
        primary_id = row.get("primary_id", None)
        if primary_id is None:
            print(f"WARNING: Row {index} is missing primary_id:")
            print(row)
            return False
        primary_id_source = row.get("primary_id_source", None)
        if primary_id_source is None:
            print(f"WARNING: Row {index} is missing primary_id_source:")
            print(row)
            return False
        session_factory = sa.orm.sessionmaker(bind=engine)
        with session_factory() as session:
            gene_i: Gene
            creator_i: User
            try:
                gene_i, creator_i = self._get_gene_and_creator(
                    session, primary_id, primary_id_source
                )
            except sa.orm.exc.NoResultFound:
                print(
                    f"Gene {primary_id} not found in the database. "
                    "Creating new gene."
                )
                gene_i, creator_i = self._create_new_gene(
                    session, primary_id, primary_id_source
                )
            try:    
                self._process_symbols(session, row, gene_i, creator_i)
                self._process_names(session, row, gene_i, creator_i)
                self._process_location(session, row, gene_i, creator_i)
                self._process_locus_type(session, row, gene_i, creator_i)
                self._process_crossrefs(session, row, gene_i, creator_i)
                if gene_i.status == GeneStatusEnum.internal:
                    print(f"Making gene {gene_i.primary_id} public")
                    gene_i.status = GeneStatusEnum.approved
                    session.add(gene_i)
                    session.flush()
                    session.refresh(gene_i)
                session.commit()
                print(f"Processed row {index}: {primary_id} successfully.")
                return True
            except Exception as e:
                print(row)
                session.rollback()
                print(f"Error processing row {index}: {e}")
                return False

    def _get_gene_and_creator(
        self, session, primary_id, primary_id_source
    ) -> tuple[Gene, User]:
        """
        Get gene and creator objects from the database.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            primary_id (str): The primary ID of the gene.
            primary_id_source (str): The source of the primary ID.

        Returns:
            tuple: (gene, creator) SQLAlchemy model objects.

        Raises:
            sqlalchemy.orm.exc.NoResultFound: If the gene or creator is not found.
        """
        gene_i = (
            session.query(Gene)
            .where(
                Gene.primary_id == primary_id,
                Gene.primary_id_source == primary_id_source
            )
            .one()
        )
        creator_i = session.query(User).where(
            User.email == "sart2@cam.ac.uk"
        ).one()
        return gene_i, creator_i

    def _create_new_gene(
        self, session, primary_id, primary_id_source,
        taxon_id=3694, creation_date=None
    ) -> tuple[Gene, User]:
        """
        Create a new gene record in the database.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            primary_id (str): The primary ID of the gene.
            primary_id_source (str): The source of the primary ID.

        Returns:
            tuple: (gene, creator) SQLAlchemy model objects.

        Raises:
            sqlalchemy.orm.exc.NoResultFound: If the creator is not found.
        """
        # Set default creation date if not provided
        if creation_date is None:
            creation_date = pandas.Timestamp.now()
        creator_i = session.query(User).where(
            User.email == "sart2@cam.ac.uk"
        ).one()
        
        # Check if the xref already exists
        xref: Xref | None = session.query(Xref).where(
            Xref.display_id == primary_id,
            Xref.ext_resource_id == 1
        ).one_or_none()
        if xref is not None:
            raise ValueError(
                f"Xref with display_id '{primary_id}' already exists in the database."
            )
        # Check if the external resource exists
        ext_res: ExternalResource = session.query(ExternalResource).where(
            ExternalResource.name == primary_id_source
        ).one()

        # Create a new gene record
        gene_i = Gene(
            taxon_id=taxon_id, # Taxon ID for Populus trichocarpa
            primary_id=primary_id,
            primary_id_source=primary_id_source,
            status=GeneStatusEnum.internal,
            creator_id=creator_i.id,
            creation_date=creation_date
        )
        session.add(gene_i)
        session.flush()
        session.refresh(gene_i)
        
        gene_id = gene_i.id
        ext_res_id = ext_res.id

        # Create a new xref record
        xref_i = Xref(
            display_id=primary_id,
            ext_res_id=ext_res_id
        )
        session.add(xref_i)
        session.flush()
        session.refresh(xref_i)

        # Create a link between the gene and the xref
        gene_has_xref_i = GeneHasXref(
            gene_id=gene_id,
            xref_id=xref_i.id,
            creator_id=creator_i.id,
            source="curator",
            status=BasicStatusEnum.public.value
        )
        session.add(gene_has_xref_i)
        session.flush()
        session.refresh(gene_has_xref_i) 

        return gene_i, creator_i

    def _process_symbols(self, session, row, gene_i, creator_i):
        """
        Process and create gene symbol records.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.

        Raises:
            ValueError: If gene_symbol_string is missing.
        """
        symbol = row.get("gene_symbol_string", None)
        if symbol is None:
            raise ValueError("gene_symbol_string is required.")

        # Process approved symbol
        try:
            self._process_approved_symbol(session, symbol, gene_i, creator_i)
        except ValueError:
            print(
                f"Gene {gene_i.primary_id} already has approved "
                f"symbol {symbol}. Skipping"
            )
        try:
            self._process_alias_symbols(session, row, gene_i, creator_i)
        except ValueError:
            print(
                f"Gene {gene_i.primary_id} already has "
                f"alias symbol {symbol}. Skipping"
            )

    def _process_approved_symbol(self, session, symbol, gene_i, creator_i):
        """
        Process and create approved gene symbol record.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            symbol (str): The symbol string to process.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.

        Raises:
            ValueError: If there are conflicts with existing symbols.
        """
        # Check if symbol already exists for gene
        existing_symbol = session.query(Symbol).filter(Symbol.symbol == symbol).first()
        if existing_symbol is None:
            # Add new symbol and link to gene
            GeneSymbol(
                session,
                symbol,
                gene_i.id,
                creator_i.id,
                NomenclatureEnum.approved.value,
                BasicStatusEnum.public.value,
            )
        else:
            # is it an approved symbol?
            if existing_symbol.symbol_has_genes is not None:
                for symbol_has_gene in existing_symbol.symbol_has_genes:
                    if symbol_has_gene.type == NomenclatureEnum.approved:
                        # approved symbol already exists
                        raise ValueError(
                            "gene_symbol_string already exists as an approved symbol for this gene."
                        )
                    if symbol_has_gene.gene_id == gene_i.id:
                        # symbol already exists for this gene
                        raise ValueError(
                            "gene_symbol_string already exists for this gene."
                            "You cannot have a symbol with two different types"
                        )
            # ADD link to gene as approved symbol
            gene_has_symbol = GeneHasSymbol(
                symbol_id=existing_symbol.id,
                gene_id=gene_i.id,
                type=NomenclatureEnum.approved,
                created_by=creator_i.id,
                status=BasicStatusEnum.public,
            )
            session.add(gene_has_symbol)
            session.flush()
            session.refresh(gene_has_symbol)

    def _process_alias_symbols(self, session, row, gene_i, creator_i):
        """
        Process and create alias gene symbol records.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.
        """
        alias_symbols = row.get("alias_gene_symbol_string", None)
        if alias_symbols is not None and not pandas.isna(alias_symbols):
            alias_symbol_list = alias_symbols.split("|")
            for alias_symbol in alias_symbol_list:
                existing_symbol = (
                    session.query(Symbol).filter(Symbol.symbol == alias_symbol).first()
                )
                if existing_symbol is None:
                    print("Alias symbol does not exist: adding new symbol")
                    GeneSymbol(
                        session=session,
                        symbol=alias_symbol,
                        gene_id=gene_i.id,
                        creator_id=creator_i.id,
                        type=NomenclatureEnum.alias.value,
                        status=BasicStatusEnum.public.value,
                    )
                else:
                    if existing_symbol.symbol_has_genes is not None:
                        skip = False
                        for symbol_has_gene in existing_symbol.symbol_has_genes:
                            if (
                                symbol_has_gene.type == NomenclatureEnum.approved
                                and symbol_has_gene.gene_id == gene_i.id
                            ):
                                raise ValueError(
                                    "alias_gene_symbol_string already exists as an approved symbol for this gene."
                                )
                            elif (
                                symbol_has_gene.type == NomenclatureEnum.alias
                                and symbol_has_gene.gene_id == gene_i.id
                            ):
                                print(
                                    f"Alias symbol {alias_symbol} already exists on gene {gene_i.primary_id}"
                                    "as an alias symbol."
                                )
                                skip = True
                                break
                            else:
                                gene_has_symbol = GeneHasSymbol(
                                    symbol_id=existing_symbol.id,
                                    gene_id=gene_i.id,
                                    type=NomenclatureEnum.alias,
                                    created_by=creator_i.id,
                                    status=BasicStatusEnum.public,
                                )
                                session.add(gene_has_symbol)
                                session.flush()
                                session.refresh(gene_has_symbol)
                                skip = True
                                break
                        if skip:
                            print("Skipping alias symbol")
                            continue
                    else:
                        print("Alias exists but not linked to gene: linking")
                        gene_has_symbol = GeneHasSymbol(
                            symbol_id=existing_symbol.id,
                            gene_id=gene_i.id,
                            type=NomenclatureEnum.alias,
                            created_by=creator_i.id,
                            status=BasicStatusEnum.public,
                        )
                        session.add(gene_has_symbol)
                        session.flush()
                        session.refresh(gene_has_symbol)

    def _process_names(self, session, row, gene_i, creator_i):
        """
        Process and create gene name records.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.

        Raises:
            ValueError: If gene_symbol_string is missing.
        """
        name = row.get("gene_name_string", None)
        if name is None:
            raise ValueError("gene_name_string is required.")
        try:
            self._process_approved_name(session, name, gene_i, creator_i)
        except ValueError:
            print(
                f"Gene {gene_i.primary_id} already has approved name {name}. Skipping"
            )
        try:
            self._process_alias_names(session, row, gene_i, creator_i)
        except ValueError:
            print(f"Gene {gene_i.primary_id} already has alias name {name}. Skipping")

    def _process_approved_name(self, session, name, gene_i, creator_i):
        """
        Process and create approved gene name record.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            name (str): The symbol string to process.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.

        Raises:
            ValueError: If there are conflicts with existing symbols.
        """
        # Check if symbol already exists for gene
        existing_name = session.query(Name).filter(Name.name == name).first()
        if existing_name is None:
            # Add new symbol and link to gene
            GeneName(
                session,
                name,
                gene_i.id,
                creator_i.id,
                NomenclatureEnum.approved.value,
                BasicStatusEnum.public.value,
            )
        else:
            if existing_name.name_has_genes is not None:
                for name_has_gene in existing_name.name_has_genes:
                    if name_has_gene.type == NomenclatureEnum.approved:
                        # approved symbol already exists
                        raise ValueError(
                            "gene_name_string already exists as an approved name for this gene."
                        )
                    if name_has_gene.gene_id == gene_i.id:
                        # symbol already exists for this gene
                        raise ValueError(
                            "gene_name_string already exists for this gene."
                            "You cannot have a name with two different types"
                        )
            gene_has_name = GeneHasName(
                name_id=existing_name.id,
                gene_id=gene_i.id,
                type=NomenclatureEnum.approved,
                created_by=creator_i.id,
                status=BasicStatusEnum.public,
            )
            session.add(gene_has_name)
            session.flush()
            session.refresh(gene_has_name)

    def _process_alias_names(self, session, row, gene_i, creator_i):
        """
        Process and create alias gene name records.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.
        """
        alias_names = row.get("alias_gene_name_string", None)
        if alias_names is not None and not pandas.isna(alias_names):
            alias_name_list = alias_names.split("|")
            for alias_name in alias_name_list:
                existing_name = (
                    session.query(Name).filter(Name.name == alias_name).first()
                )
                if existing_name is None:
                    print("Alias name does not exist: adding new name")
                    GeneName(
                        session=session,
                        name=alias_name,
                        gene_id=gene_i.id,
                        creator_id=creator_i.id,
                        type=NomenclatureEnum.alias.value,
                        status=BasicStatusEnum.public.value,
                    )
                else:
                    if existing_name.name_has_genes is not None:
                        skip = False
                        for name_has_gene in existing_name.name_has_genes:
                            if (
                                name_has_gene.type == NomenclatureEnum.approved
                                and name_has_gene.gene_id == gene_i.id
                            ):
                                raise ValueError(
                                    "alias_gene_name_string already exists as an approved name for this gene."
                                )
                            elif (
                                name_has_gene.type == NomenclatureEnum.alias
                                and name_has_gene.gene_id == gene_i.id
                            ):
                                print(
                                    f"Alias name {alias_name} already exists on gene {gene_i.primary_id}"
                                    "as an alias name."
                                )
                                skip = True
                                break
                            else:
                                gene_has_name = GeneHasName(
                                    name_id=existing_name.id,
                                    gene_id=gene_i.id,
                                    type=NomenclatureEnum.alias,
                                    created_by=creator_i.id,
                                    status=BasicStatusEnum.public,
                                )
                                session.add(gene_has_name)
                                session.flush()
                                session.refresh(gene_has_name)
                                skip = True
                                break
                        if skip:
                            print("Skipping alias name")
                            continue
                    else:
                        print("Alias exists but not linked to gene: linking")
                        gene_has_name = GeneHasName(
                            name_id=existing_name.id,
                            gene_id=gene_i.id,
                            type=NomenclatureEnum.alias,
                            created_by=creator_i.id,
                            status=BasicStatusEnum.public,
                        )
                        session.add(gene_has_name)
                        session.flush()
                        session.refresh(gene_has_name)

    def _process_location(self, session, row, gene_i, creator_i):
        """
        Process and create gene location record.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.
        """
        location = row.get("chromosome", None)
        if location is not None and not pandas.isna(location):
            exists = (
                session.query(Location)
                .filter(
                    Location.name == location,
                    Location.coord_system == "chromosome",
                    Location.type == "primary assembly",
                )
                .first()
            )
            if exists is None:
                raise ValueError(
                    f"Chromosome {location} does not exist in the database."
                )

            link_exists = (
                session.query(GeneHasLocation)
                .filter(
                    GeneHasLocation.gene_id == gene_i.id,
                    GeneHasLocation.location_id == exists.id,
                )
                .first()
            )
            if link_exists is not None:
                print(
                    f"Gene {gene_i.primary_id} already has the chromosome '{location}'. "
                    "skipping chromosome."
                )
                return

            # Create the link between gene and locus type
            gene_has_location_i = GeneHasLocation(
                gene_id=gene_i.id,
                location_id=exists.id,
                creator_id=creator_i.id,
                status=BasicStatusEnum.public,
            )
            session.add(gene_has_location_i)
            session.flush()
            session.refresh(gene_has_location_i)
        else:
            raise ValueError(f"Chromosome is required {gene_i.primary_id}.")

    def _process_locus_type(self, session, row, gene_i, creator_i):
        """
        Process and create gene locus type record.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.

        Raises:
            ValueError: If locus_type is missing.
        """
        locus_type = row.get("locus_type", None)
        if locus_type is not None and not pandas.isna(locus_type):
            exists = (
                session.query(LocusType).filter(LocusType.name == locus_type).first()
            )
            if exists is None:
                raise ValueError(
                    f"Locus type {locus_type} does not exist in the database."
                )

            link_exists = (
                session.query(GeneHasLocusType)
                .filter(
                    GeneHasLocusType.gene_id == gene_i.id,
                    GeneHasLocusType.locus_type_id == exists.id,
                )
                .first()
            )
            if link_exists is not None:
                print(
                    f"gene {gene_i.primary_id} already has a locus type '{locus_type}'. "
                    "Skipping locus type."
                )
                return

            # Create the link between gene and locus type
            gene_has_locus_type_i = GeneHasLocusType(
                gene_id=gene_i.id,
                locus_type_id=exists.id,
                creator_id=creator_i.id,
                status=BasicStatusEnum.public,
            )
            session.add(gene_has_locus_type_i)
            session.flush()
            session.refresh(gene_has_locus_type_i)

        else:
            raise ValueError(f"Locus Type is required {gene_i.primary_id}.")

    def _process_crossrefs(self, session, row, gene_i, creator_i):
        """
        Process and create gene cross-reference records.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.
        """
        # Process NCBI gene IDs
        self._process_xref_field(session, row, "ncbi_gene_id", 1, gene_i, creator_i)

        # Process UniProt IDs
        self._process_xref_field(session, row, "uniprot_id", 3, gene_i, creator_i)

        # Process PubMed IDs
        self._process_xref_field(session, row, "pubmed_id", 4, gene_i, creator_i)

    def _process_xref_field(
        self, session, row, field_name, xref_type, gene_i, creator_i
    ):
        """
        Process and create gene cross-references of a specific type.

        Args:
            session (sqlalchemy.orm.Session): SQLAlchemy database session.
            row (pandas.Series): The DataFrame row containing gene data.
            field_name (str): Name of the field containing the cross-references.
            xref_type (int): Type ID of the cross-reference.
            gene_i (Gene): The gene model object.
            creator_i (User): The creator user model object.
        """
        xref_ids = row.get(field_name, None)
        if xref_ids is not None and not pandas.isna(xref_ids):
            xref_id_list = xref_ids.split("|")
            skip_id_list = False
            for xref_display_id in xref_id_list:
                exists = (
                    session.query(Xref)
                    .filter(
                        Xref.display_id == xref_display_id,
                        Xref.ext_resource_id == xref_type,
                    )
                    .first()
                )
                if exists is not None:
                    for xref_has_gene in exists.xref_has_genes:
                        if xref_has_gene.gene_id == gene_i.id:
                            print(
                                f"Xref {xref_display_id} already exists for gene {gene_i.primary_id}. Skipping."
                            )
                            skip_id_list = True
                            break
                    if skip_id_list:
                        break

                    if xref_type == 4:
                        gene_has_xref_id = GeneHasXref(
                            gene_id=gene_i.id,
                            xref_id=exists.id,
                            creator_id=creator_i.id,
                            source="curator",
                            status=BasicStatusEnum.public,
                        )
                        session.add(gene_has_xref_id)
                        session.flush()
                        session.refresh(gene_has_xref_id)
                    else:
                        raise ValueError(
                            f"Xref with display_id '{xref_display_id}' and ext_resource_id '{xref_type}' already "
                            f"exists. UniProt IDs and NCBI Gene IDs have a one to one relationship with gene."
                        )
                else:
                    GeneXref(
                        session=session,
                        display_id=xref_display_id,
                        ext_res_id=xref_type,
                        gene_id=gene_i.id,
                        creator_id=creator_i.id,
                        source="curator",
                        status=BasicStatusEnum.public.value,
                    )


def dump_db(cmd: tuple[str, ...], file_name: str):
    """
    Dump database content to a gzipped file.
    This function executes a database dump command as a subprocess and
    writes its output to a gzipped file in the '/usr/src/app/db-data/' directory.
    Args:
        cmd (tuple[str, ...]): Command to execute as a subprocess.
            This should be the database dump command and its arguments.
        file_name (str): Name of the file where the output will be saved.
            The file will be created in '/usr/src/app/db-data/'.
    Returns:
        None
    Note:
        The function assumes the provided command outputs text that can be encoded as UTF-8.
        The subprocess's stdout is read line by line and written to the gzipped file.
    """

    with gzip.open(f"/usr/src/app/db-data/{file_name}", "wb") as f:
        # with open("backup.sql", "w") as f:
        popen = subprocess.Popen(cmd, stdout=subprocess.PIPE, universal_newlines=True)
        print("dump_db running")
        if popen.stdout is not None:
            for stdout_line in iter(popen.stdout.readline, ""):
                f.write(stdout_line.encode("utf-8"))
                # f.write(stdout_line)

            popen.stdout.close()
        popen.wait()


def main():
    """
    Main function to handle command-line arguments and execute CSV parsing and data processing.

    This function parses command-line arguments to get the CSV file path,
    creates a GeneDataLoader instance, and processes the gene data.

    Command line arguments:
        --file: Path to the CSV file containing gene data.

    Returns:
        None

    Exit codes:
        1: If the CSV file could not be loaded or parsed.
    """
    parser = argparse.ArgumentParser(
        description="Parse a CSV file containing gene data."
    )
    parser.add_argument("--file", type=str, help="Path to the CSV file.")
    args = parser.parse_args()

    # Load and process the gene data
    data_loader = GeneDataLoader(args.file)
    if data_loader.df is None:
        exit(1)
    try:
        data_loader.process_data()
    except Exception as e:
        print(f"Error processing data: {e}")
        exit(1)
    print("Dumping database...")
    try:
        dump_db(
            (
                "pg_dump",
                "-h",
                os.environ["DB_HOST"],
                "-p",
                os.environ["DB_PORT"],
                "-U",
                os.environ["DB_USER"],
                "-d",
                os.environ["DB_NAME"],
            ),
            "01-pgncdb.sql.gz",
        )
    except Exception as e:
        print(f"Error dumping database: {e}")
        exit(1)
    print("Database dump complete.")


if __name__ == "__main__":
    main()
