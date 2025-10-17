from typing import Literal

from db.models.location import Location
from db.models.gene_has_location import GeneHasLocation


class GeneLocation:
    def __init__(
        self,
        session,
        location_name: str,
        gene_id: int,
        creator_id: int,
        status: Literal["public", "private"],
    ):
        location_i: Location = (
            session.query(Location).where(Location.name == location_name).one()
        )
        gene_has_location_i = self._create_gene_has_location(
            session, gene_id, location_i.id, creator_id, status
        )
        self.location_id = location_i.id
        self.gene_id = gene_id
        self.creator_id = creator_id
        self.status = status
        self.creation_date = gene_has_location_i.creation_date

    def _create_gene_has_location(
        self,
        session,
        gene_id: int,
        location_id: int,
        creator_id: int,
        status: Literal["public", "private"],
    ):
        gene_has_location_i = GeneHasLocation(
            gene_id=gene_id,
            location_id=location_id,
            creator_id=creator_id,
            status=status,
        )
        session.add(gene_has_location_i)
        session.flush()
        session.refresh(gene_has_location_i)
        return gene_has_location_i

    def __repr__(self):
        return (
            f"<GeneLocation(location_id={self.location_id}, "
            f"gene_id={self.gene_id}, creator_id={self.creator_id}, "
            f"status='{self.status}', creation_date={self.creation_date})>"
        )
