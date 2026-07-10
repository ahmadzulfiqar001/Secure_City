from pydantic import BaseModel, Field


class ContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    relation: str = Field(min_length=1, max_length=60)
    phone: str = Field(min_length=1, max_length=32)


class ContactUpdate(ContactCreate):
    pass


class ContactOut(BaseModel):
    id: int
    name: str
    relation: str
    phone: str

    model_config = {"from_attributes": True}
