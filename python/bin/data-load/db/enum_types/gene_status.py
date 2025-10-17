import enum

class GeneStatusEnum(enum.Enum):
    internal = "internal"
    approved = "approved"
    withdrawn = "withdrawn"
    review = "review"
    merged = "merged"
    split = "split"
