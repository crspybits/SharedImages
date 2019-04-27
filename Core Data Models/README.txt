4/20/18
    * I have migrated from version 7 to 8 of the model, and made a couple of parent (abstract) entities. This required use of a mapping model. See references:
        http://www.barbararodeker.com/ladyandtech/?p=221
        https://stackoverflow.com/questions/8250975/how-to-refactor-a-core-data-model-to-make-two-existing-entities-inherit-from-a-n

    * One complicated area within this was mapping a relationship from a prior entity to a new entity.
        https://stackoverflow.com/questions/13945704/ios-what-is-the-value-expression-function-when-migrating-coredata-relationship?rq=1

    * More specifically, I'm having problems getting the relations to migrate. I asked a question on this here:
    https://stackoverflow.com/questions/55777478/how-do-you-map-abstracted-relationships-with-a-core-data-mapping-model

    * All of the other (non-relation) attributes appear to migrate properly. To fix this, I have added a manual migration step-- see Migrations.v1_5.boolValue in Migrations based on fileGroupUUID.
