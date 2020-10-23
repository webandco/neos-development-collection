<?php

namespace Neos\Neos\Aspects;

use Doctrine\ORM\EntityManagerInterface;
use Neos\ContentRepository\Domain\Model\NodeData;
use Neos\Flow\Annotations as Flow;
use Neos\Flow\Aop\JoinPointInterface;
use Flownative\Neos\HostBasedDefaultPreset\Service\ConfigurationContentDimensionPresetSource;
use Neos\Flow\Log\PsrSystemLoggerInterface;
use Neos\Flow\Persistence\PersistenceManagerInterface;
use Neos\Media\Domain\Model\AssetInterface;
use Neos\Media\Domain\Model\Image;
use Neos\Neos\Domain\Service\SiteService;
use Neos\Utility\TypeHandling;

/**
 * @Flow\Scope("singleton")
 * @Flow\Aspect
 */
class AssetUsageInNodePropertiesStrategyAspect
{
    /**
     * @var array
     */
    protected $firstlevelCache = [];

    /**
     * @Flow\Inject
     * @var PsrSystemLoggerInterface
     */
    protected $systemLogger;

    /**
     * @Flow\Inject
     * @var PersistenceManagerInterface
     */
    protected $persistenceManager;

    /**
     * Doctrine's Entity Manager.
     *
     * @Flow\Inject
     * @var EntityManagerInterface
     */
    protected $entityManager;


    /**
     *
     * @Flow\Around("method(Neos\Neos\Domain\Strategy\AssetUsageInNodePropertiesStrategy->getRelatedNodes())")
     * @param JoinPointInterface $joinPoint The current join point
     * @return void
     */
    public function getRelatedNodes(JoinPointInterface $joinPoint)
    {
        $this->systemLogger->debug('ASPECT['.__CLASS__.']');

        /** @var AssetInterface $site */
        $asset = $joinPoint->getMethodArgument('asset');

        // first level cache is useful, because isInUse() and getUsageCount() both use getRelatedNodes()
        $assetIdentifier = $this->persistenceManager->getIdentifierByObject($asset);
        if (isset($this->firstlevelCache[$assetIdentifier])) {
            return $this->firstlevelCache[$assetIdentifier];
        }

        // query the database for all site related nodes that have __identifier or asset:// set in the properties
        $sql =  'SELECT persistence_object_identifier, properties FROM neos_contentrepository_domain_model_nodedata';
        $sql .= ' WHERE ';
        $sql .= '   (properties LIKE \'%\_\_identifier%\' OR properties LIKE \'%asset:\\\\\\\\/\\\\\\\\/%\')';
        $sql .= '   AND path like \''.SiteService::SITES_ROOT_PATH.'%\'';

        /** @var \Doctrine\ORM\QueryBuilder $queryBuilder */
        $queryBuilder = $this->entityManager->createQueryBuilder();
        $nodeList     = $queryBuilder->getEntityManager()->getConnection()->query($sql)->fetchAll();

        // rearrange the query result
        $nodes = [];
        foreach ($nodeList as $row) {
            $nodes[$row['persistence_object_identifier']] = $row['properties'];
        }

        $assetsToNodes = [];

        // exctract the asset identifiers from the properties
        foreach ($nodes as $poid => $properties) {
            $matches = [];
            if (preg_match_all('/"__identifier": "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"/s', $properties, $matches)) {
                foreach ($matches[1] as $uuid) {
                    $assetsToNodes[$uuid][] = $poid;
                }
            }

            $matches = [];
            if (preg_match_all('/asset:\\\\\\/\\\\\\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"/s', $properties, $matches)) {
                foreach ($matches[1] as $uuid) {
                    $assetsToNodes[$uuid][] = $poid;
                }
            }

            $assetsToNodes[$uuid] = array_unique($assetsToNodes[$uuid]);
        }

        $identifiersToSearch = [];

        // get the image identifier itself
        $poid = $this->persistenceManager->getIdentifierByObject($asset);
        $identifiersToSearch[] = $poid;

        if ($asset instanceof Image) {
            // collect the variant identifiers
            foreach ($asset->getVariants() as $variant) {
                $poid = $this->persistenceManager->getIdentifierByObject($variant);
                $identifiersToSearch[] = $poid;
            }
        }

        // get the relevant NodeData objects from the database
        $finalNodes = [];
        foreach ($identifiersToSearch as $uuid) {
            if (!isset($assetsToNodes[$uuid])) {
                continue;
            }

            foreach ($assetsToNodes[$uuid] as $poid) {
                if (isset($finalNodes[$poid])) {
                    continue;
                }

                $finalNodes[$poid] = $this->persistenceManager->getObjectByIdentifier($poid, NodeData::class);
            }
        }

        $this->firstlevelCache[$assetIdentifier] = array_values($finalNodes);
        return $this->firstlevelCache[$assetIdentifier];
    }
}
