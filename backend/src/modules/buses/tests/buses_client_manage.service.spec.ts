/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-return */
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { BusesClientManageService } from '../buses_client_manage.service';

describe('BusesClientManageService Unit Tests', () => {
  let service: BusesClientManageService;
  let mockBusesRepo: any;
  let mockLayoutsRepo: any;
  let mockBusTypesRepo: any;
  let mockAmenitiesService: any;
  let mockChangesRunner: any;
  let mockConnection: any;

  const operatorId = new Types.ObjectId();
  const actor: AuthenticatedUserActor = ({
    userId: new Types.ObjectId().toHexString(),
    actorType: 'USER',
    userType: 'OPERATOR',
    operatorId: operatorId.toHexString(),
    permissions: ['buses.read', 'buses.create', 'buses.update'],
  } as unknown) as AuthenticatedUserActor;

  beforeEach(() => {
    mockBusesRepo = {
      getById: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      insertOne: jest.fn(),
      updateOne: jest.fn(),
    };
    mockLayoutsRepo = {
      findById: jest.fn(),
      findLatestForBus: jest.fn(),
      getById: jest.fn(),
    };
    mockBusTypesRepo = {
      findById: jest.fn(),
      findMany: jest.fn(),
    };
    mockAmenitiesService = {
      assertUsable: jest.fn(),
    };
    mockChangesRunner = {
      run: jest.fn().mockImplementation((args) => args.apply({})),
    };
    mockConnection = {
      model: jest.fn().mockReturnValue({
        find: jest.fn().mockReturnValue({
          lean: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
        create: jest.fn().mockImplementation(([doc]) => [{ ...doc, _id: new Types.ObjectId() }]),
      }),
      collection: jest.fn().mockReturnValue({
        countDocuments: jest.fn().mockResolvedValue(0),
      }),
    };

    service = new BusesClientManageService(
      mockBusesRepo,
      mockLayoutsRepo,
      mockBusTypesRepo,
      mockAmenitiesService,
      mockChangesRunner,
      mockConnection,
    );
  });

  describe('getLayoutForBus', () => {
    it('returns preview layout if no layout exists yet for the bus', async () => {
      const busId = new Types.ObjectId().toHexString();
      mockBusesRepo.getById.mockResolvedValue({
        _id: new Types.ObjectId(busId),
        operatorId,
        seatCapacity: 40,
        seatLayoutType: '2+2 Seater',
      });
      mockLayoutsRepo.findLatestForBus.mockResolvedValue(null);

      const layout = await service.getLayoutForBus(actor, busId);

      expect(layout.busId).toBe(busId);
      expect(layout.totalSeats).toBe(40);
      expect(layout.layoutType).toBe('2+2 Seater');
      expect(layout.map.length).toBe(10);
    });

    it('throws if bus belongs to another operator', async () => {
      const busId = new Types.ObjectId().toHexString();
      mockBusesRepo.getById.mockResolvedValue({
        _id: new Types.ObjectId(busId),
        operatorId: new Types.ObjectId(), // Different operator
      });

      await expect(service.getLayoutForBus(actor, busId)).rejects.toThrow(ApiException);
    });
  });

  describe('saveLayout', () => {
    it('creates version 1 if no existing version exists', async () => {
      const busId = new Types.ObjectId().toHexString();
      mockBusesRepo.getById.mockResolvedValue({
        _id: new Types.ObjectId(busId),
        operatorId,
        seatCapacity: 40,
        seatLayoutType: '2+2 Seater',
      });
      mockLayoutsRepo.findLatestForBus.mockResolvedValue(null);

      const result = await service.saveLayout(
        actor,
        busId,
        {
          name: 'New Custom Layout',
          layoutType: '2+2 Seater',
          decks: 1,
          map: ['SS_SS', 'SS_SS'],
        },
        {} as any,
      );

      expect(result).toBeDefined();
      expect(mockBusesRepo.updateOne).toHaveBeenCalledWith(
        { _id: new Types.ObjectId(busId) },
        expect.objectContaining({
          $set: expect.objectContaining({
            seatCapacity: 8,
            seatLayoutType: '2+2 Seater',
          }),
        }),
        expect.anything(),
      );
    });
  });
});
