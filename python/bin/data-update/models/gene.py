class Gene:

    def __init__(self):
        self.__pgnc_id: int = None
        self.__taxon_id: int = None
        self.__chromosome: str = None
        self.__gene_symbol_string: str = None
        self.__gene_name_string: str = None
        self.__locus_type: list[str] = None
        self.__status: str = None
        self.__alias_gene_symbol_string: list[str] = None
        self.__alias_gene_name_string: list[str] = None
        self.__prev_gene_symbol_string: list[str] = None
        self.__prev_gene_name_string: list[str] = None
        self.__phytozome_id: list[str] = None
        self.__ncbi_gene_id: list[int] = None
        self.__ensembl_gene_id: list[str] = None
        self.__uniprot_id: list[str] = None
        # self.__pubmed_id: list[int] = None
        self.__primary_id: str = None

    @property
    def pgnc_id(self):
        return self.__pgnc_id

    @pgnc_id.setter
    def pgnc_id(self, value: int):
        self.__pgnc_id = value

    @property
    def primary_id(self):
        return self.__primary_id

    @primary_id.setter
    def primary_id(self, value: str):
        self.__primary_id = value

    @property
    def taxon_id(self):
        return self.__taxon_id

    @taxon_id.setter
    def taxon_id(self, value: int):
        self.__taxon_id = value

    @property
    def chromosome(self):
        return self.__chromosome

    @chromosome.setter
    def chromosome(self, value: str):
        self.__chromosome = value

    @property
    def gene_symbol_string(self):
        return self.__gene_symbol_string

    @gene_symbol_string.setter
    def gene_symbol_string(self, value: list[str]):
        self.__gene_symbol_string = value

    @property
    def gene_name_string(self):
        return self.__gene_name_string

    @gene_name_string.setter
    def gene_name_string(self, value: list[str]):
        self.__gene_name_string = value

    @property
    def locus_types(self):
        return self.__locus_type

    @locus_types.setter
    def locus_types(self, value: list[str]):
        self.__locus_type = value

    @property
    def status(self):
        return self.__status

    @status.setter
    def status(self, value: str):
        self.__status = value

    @property
    def alias_gene_symbol_string(self):
        return self.__alias_gene_symbol_string

    @alias_gene_symbol_string.setter
    def alias_gene_symbol_string(self, value: list[str]):
        self.__alias_gene_symbol_string = value

    @property
    def alias_gene_name_string(self):
        return self.__alias_gene_name_string

    @alias_gene_name_string.setter
    def alias_gene_name_string(self, value: list[str]):
        self.__alias_gene_name_string = value

    @property
    def prev_gene_symbol_string(self):
        return self.__prev_gene_symbol_string

    @prev_gene_symbol_string.setter
    def prev_gene_symbol_string(self, value: list[str]):
        self.__prev_gene_symbol_string = value

    @property
    def prev_gene_name_string(self):
        return self.__prev_gene_name_string

    @prev_gene_name_string.setter
    def prev_gene_name_string(self, value: list[str]):
        self.__prev_gene_name_string = value

    @property
    def phytozome_id(self):
        return self.__phytozome_id

    @phytozome_id.setter
    def phytozome_id(self, value:list[str]):
        self.__phytozome_id = value

    @property
    def ncbi_gene_id(self):
        return self.__ncbi_gene_id

    @ncbi_gene_id.setter
    def ncbi_gene_id(self, value: list[int]):
        self.__ncbi_gene_id = value

    @property
    def ensembl_gene_id(self):
        return self.__ensembl_gene_id

    @ensembl_gene_id.setter
    def ensembl_gene_id(self, value: list[str]):
        self.__ensembl_gene_id = value

    @property
    def uniprot_id(self):
        return self.__uniprot_id

    @uniprot_id.setter
    def uniprot_id(self, value: list[str]):
        self.__uniprot_id = value

    # @property
    # def pubmed_id(self):
    #     return self.__pubmed_id

    # @pubmed_id.setter
    # def pubmed_id(self, value: list[int]):
    #     self.__pubmed_id = value

    def to_dict(self) -> dict:
        return {
            'pgnc_id': f'PGNC:{self.__pgnc_id}',
            'taxon_id': self.__taxon_id,
            'chromosome': self.__chromosome,
            'gene_symbol_string': self.__gene_symbol_string,
            'gene_name_string': self.__gene_name_string,
            'locus_type': self.__locus_type,
            'status': self.__status,
            'alias_gene_symbol_string': self.__alias_gene_symbol_string,
            'alias_gene_name_string': self.__alias_gene_name_string,
            'prev_gene_symbol_string': self.__prev_gene_symbol_string,
            'prev_gene_name_string': self.__prev_gene_name_string,
            'phytozome_id': self.__phytozome_id,
            'ncbi_gene_id': self.__ncbi_gene_id,
            'ensembl_gene_id': self.__ensembl_gene_id,
            'uniprot_id': self.__uniprot_id,
            # 'pubmed_id': self.__pubmed_id,
            'primary_id': self.__primary_id
        }