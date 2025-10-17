from typing import Literal

from db.models.gene_has_name import GeneHasName
from db.models.name import Name


class GeneName:
    def __init__(
        self,
        session,
        name: str,
        gene_id: int,
        creator_id: int,
        type: Literal["approved", "alias", "previous"],
        status: Literal["public", "private"],
    ):
        name_i = self._create_name(session, name)
        gene_has_name_i = self._create_gene_has_name(
            session, gene_id, name_i.id, type, creator_id, status
        )
        self.name_id = name_i.id
        self.gene_id = gene_id
        self.creator_id = creator_id
        self.type = type
        self.status = status
        self.creation_date = gene_has_name_i.creation_date

    def _create_name(self, session, name: str):
        name_i = Name(name=name)
        session.add(name_i)
        session.flush()
        session.refresh(name_i)
        return name_i

    def _create_gene_has_name(
        self,
        session,
        gene_id: int,
        name_id: int,
        type: Literal["approved", "alias", "previous"],
        creator_id: int,
        status: Literal["public", "private"],
    ):
        gene_has_name_i = GeneHasName(
            gene_id=gene_id,
            name_id=name_id,
            type=type,
            creator_id=creator_id,
            status=status,
        )
        session.add(gene_has_name_i)
        session.flush()
        session.refresh(gene_has_name_i)
        return gene_has_name_i

    def __repr__(self):
        return (
            f"<GeneName(name_id={self.name_id}, "
            f"gene_id={self.gene_id}, creator_id={self.creator_id}, "
            f"type='{self.type}', status='{self.status}', "
            f"creation_date={self.creation_date})>"
        )
