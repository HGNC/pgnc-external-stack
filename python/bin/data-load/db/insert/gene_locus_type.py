from typing import Literal

from db.models.locus_type import LocusType
from db.models.gene_has_locus_type import GeneHasLocusType


class GeneLocusType:
    def __init__(
        self,
        session,
        locus_type_name: str,
        gene_id: int,
        creator_id: int,
        status: Literal["public", "private"],
    ):
        locus_type_i: LocusType = (
            session.query(LocusType).where(LocusType.name == locus_type_name).one()
        )
        gene_has_locus_type_i = self._create_gene_has_locus_type(
            session, gene_id, locus_type_i.id, creator_id, status
        )
        self.locus_type_id = locus_type_i.id
        self.gene_id = gene_id
        self.creator_id = creator_id
        self.status = status
        self.creation_date = gene_has_locus_type_i.creation_date

    def _create_gene_has_locus_type(
        self,
        session,
        gene_id: int,
        locus_type_id: int,
        creator_id: int,
        status: Literal["public", "private"],
    ):
        gene_has_locus_type_i = GeneHasLocusType(
            gene_id=gene_id,
            locus_type_id=locus_type_id,
            creator_id=creator_id,
            status=status,
        )
        session.add(gene_has_locus_type_i)
        session.flush()
        session.refresh(gene_has_locus_type_i)
        return gene_has_locus_type_i

    def __repr__(self):
        return (
            f"<GeneLocusType(locus_type_id={self.locus_type_id}, "
            f"gene_id={self.gene_id}, creator_id={self.creator_id}, "
            f"status='{self.status}', creation_date={self.creation_date})>"
        )
